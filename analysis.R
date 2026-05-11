## enrich ----

# Analysis: John Oliver ---------------------------------------------------

## Sandboxing the data - to be moved to index.Rmd for publication

# Prelims -----------------------------------------------------------------

rm(list=ls(all=TRUE))
library(tidyverse)
library(viridisLite)

alignments <- read_tsv('data/alignments.csv')
episodes <- read_tsv('data/episodes.csv')

# number of episodes/seasons:
alignments |> group_by(season) |> select(season, ep_id) |> distinct() |> count(season)

# adds duration, pauses, medians
alignments <- alignments |> 
  group_by(ep_id) |> 
  # normalize 
  mutate(beg = round(beg, 4),
         end = round(end, 4)) |> 
  mutate(pause_before = beg - lag(end),
         pause_after = lead(beg) - end,
         dur = end - beg) |> 
  mutate(syl = nsyllable::nsyllable(word)) |> 
  mutate(syl_per_sec = (1/dur)*syl) |> 
  mutate(roll_mean = zoo::rollmean(syl_per_sec, 10, na.pad = T),
         roll_median = zoo::rollmedian(syl_per_sec, 10, na.pad = T),
         roll_mn = zoo::rollapply(syl_per_sec, width=3, FUN=function(x) mean(x, na.rm=TRUE), by=1, by.column=TRUE, partial=TRUE, fill=NA, align="right"))

# segment summary
alignments_summ <- alignments |> 
  # filter durations of less than 0.2 (likely alignment errors):
  filter(dur > 0.19 | is.na(dur)) |> 
  group_by(season, ep_id, ytdate, ytid) |> 
  summarize(words = n(),
            sum_na = sum(is.na(beg)),
            align_errors = sum_na/words,
            seg_length = max(end, na.rm = T)/60,
            seg_dur = sum(dur, na.rm = T)/60,
            seg_paus = sum(pause_before, pause_after, na.rm = T)/60,
            sps_mean = mean(syl_per_sec, na.rm = T),
            wpm_mean = words/seg_length,
            pause_mean = mean(pause_before, na.rm = T),
            pause_md = median(pause_before, na.rm = T),
            roll_mean = mean(roll_mean, na.rm = T),
            roll_median = median(roll_median, na.rm = T),
            dur_paus_ratio = seg_paus/seg_length)

alignments |> 
  ungroup(ep_id) |> 
  group_by(season) |>
  filter(word == "people") |> 
  summarize(dur_avg = mean(dur, na.rm = TRUE),
            freq = n()) |> 
  ggplot(aes(season, dur_avg)) +
  geom_point()

# For wpm on episodes:
episodes <- episodes |> 
  mutate(viewers_m = viewers * 1000000,
         wpm = wrds/length * 60,
         spm = syls/length,
         vlr = likes/views,
         vcr = comms/views)

# Step 4: Visualizations --------------------------------------------------

## Words per minute per episode
episodes |> 
  filter(!is.na(wpm)) |> 
  group_by(season) |> 
  summarise(median(wpm),
            median(length))
episodes |> 
  filter(!is.na(wpm)) |> 
  group_by(period) |> 
  summarise(mean(wpm),
            median(length))

episodes |> 
  filter(!(is.na(wpm))) |> 
  filter(ytdate != "2021-08-16") |> 
  #group_by(season) |>
  #slice_sample(n = 10) |>
  #ungroup() |> 
  group_by(period) |> 
  select(wpm, ytdate, wrds, length, period) |> 
  ggplot(aes(ytdate, wpm, color = length)) +
  geom_point(alpha = 1, size = 3) +
  labs(
    title = "Last Week Tonight: faster!",
    subtitle = "John Oliver's pace has increased from 150 to almost 180 words per minute",
    x = '',
    y = 'Words per minute',
    caption = "Each dot one episode; based on 299 auto-generated subtitle files."
  ) +
  scale_color_viridis_c(option = "viridis") +
  scale_size_continuous(trans = "log10") +
  coord_cartesian(ylim = c(100, 200)) +
  scale_x_date(date_breaks = '1 year', date_labels = "%Y") +
  scale_y_continuous(breaks = seq(100, 200, by = 10)) +
  hrbrthemes::theme_ipsum_gs() +
  theme(
    legend.position = "top",
    legend.direction = "horizontal",
    panel.grid.minor = element_blank()
  ) +
  guides(
    size = "none",
    color = guide_colorbar(
      title = "Segment length (in words)",
      title.position = "top",
      direction = "horizontal",
      barwidth = unit(12, "cm"),
      barheight = unit(0.2, "cm")
    )
  ) +
  geom_vline(
    xintercept = as.Date(c("2020-03-10", "2021-09-01")),
    linetype = "dashed",
    color = "black",
    linewidth = 0.8
  ) +
  annotate(
    "label",
    x = as.Date("2020-12-01"),
    y = 150,
    label = "Covid",
    fill = "white",
    color = "grey45"
  )

ggsave("data/graphs/LWT_overall.png", width = 7.2, height = 5, dpi = 300)
ggsave("data/graphs/LWT_overall.jpg", width = 7.2, height = 5)

## ---- Combine syllables and pauses in one plot ----

# correlation alignment errors & syllables
cor_ae_syls <- cor.test(alignments_summ)
alignments_summ |> 
  ungroup() |> 
  filter(pause_mean < 0.20) |> 
  select(pause_mean, sps_mean, align_errors) |> 
  cor(use = "complete.obs")


alignments_summ |> 
  # exclude all where the mean of pauses in an episode is greater than 200ms
  filter(pause_mean < .20) |> 
  select(ep_id, align_errors, pause_mean, sps_mean) |> 
  # pivot longer to make a facet plot
  pivot_longer(pause_mean:sps_mean,
               names_to = "metric",
               values_to = "value") |> 
  # change order of metrics to have syllables first in plot
  mutate(metric = factor(metric, levels = c("sps_mean", "pause_mean"))) |> 
  # change from seconds (decimal) to milliseconds
  mutate(value = if_else(metric == "pause_mean", value * 1000, value)) |>
  # scatterplot
  ggplot(aes(ytdate, value)) +
  geom_point() +
  geom_smooth(method = "lm", color = "#b73779") +
  facet_wrap(~metric, scale = "free_y", nrow = 2,
             labeller = as_labeller(c(sps_mean = "Syllables per second", pause_mean = "Pause duration in milliseconds"))) +
  labs(title = "More syllables per second and shorter pauses",
       subtitle = "Additional indicators of faster speaking rate over time\nthat are independent of show segment properties",
       x = '',
       y = '',
       caption = "108 episodes with forced-alignment") +
  scale_x_date(date_breaks = '1 year', date_labels = "%Y") +
  theme(panel.grid.minor = element_blank()) +
  hrbrthemes::theme_ipsum_gs()





## ---- Syllables ----
alignments_summ |>
  ungroup() |> 
  filter(pause_mean < 0.20) |> 
  ggplot(aes(x = ytdate, y = sps_mean, color = words)) +
  geom_point(alpha = 1, size = 3) +
  labs(
    title = "Last Week Tonight: faster and faster!",
    subtitle = "John Oliver's speaking pace has increased from 150 wpm to almost 180 wpm",
    x = '',
    y = 'Average syllables per minute',
    caption = 'Based on subtitle files — extreme outlier due to a faulty subtitle file.'
  ) +
  scale_color_viridis_c(option = "viridis") +
  scale_size_continuous(trans = "log10") +
  coord_cartesian(ylim = c(4.25, 5.25)) +
  scale_x_date(date_breaks = '1 year', date_labels = "%Y") +
  hrbrthemes::theme_ipsum_gs() +
  theme(
    legend.position = "top",
    legend.direction = "horizontal",
    plot.title = element_text(hjust = 0),
    plot.margin = margin(10, 10, 10, 0)
  ) +
  guides(
    size = "none",
    color = guide_colorbar(
      title = "Segment length (in words)",
      title.position = "top",
      direction = "horizontal",
      barwidth = unit(12, "cm"),
      barheight = unit(0.2, "cm")
    )
  ) +
  geom_vline(
    xintercept = as.Date(c("2020-03-10", "2021-09-01")),
    linetype = "dashed",
    color = "black",
    linewidth = 0.8
  ) +
  annotate(
    "label",
    x = as.Date("2020-12-01"),
    y = 150,
    label = "Covid",
    fill = "white",
    color = "grey45"
  )
ggsave("data/graphs/LWT_pauses.jpg", width = 7.2, height = 5, dpi = 300)

## ---- Pauses ----
alignments_summ |>
  ungroup() |> 
  filter(pause_mean < 0.20) |> 
  ggplot(aes(x = ytdate, y = pause_mean, color = words)) +
  geom_point(alpha = 1, size = 3) +
  labs(
    title = "Last Week Tonight: faster and faster!",
    subtitle = "John Oliver's speaking pace has increased from 150 wpm to almost 180 wpm",
    x = '',
    y = 'Average pause between words in milliseconds',
    caption = 'Based on subtitle files — extreme outlier due to a faulty subtitle file.'
  ) +
  scale_color_viridis_c(option = "viridis") +
  scale_size_continuous(trans = "log10") +
  coord_cartesian(ylim = c(0, 0.12)) +
  scale_x_date(date_breaks = '1 year', date_labels = "%Y") +
  hrbrthemes::theme_ipsum_gs() +
  theme(
    legend.position = "top",
    legend.direction = "horizontal",
    plot.title = element_text(hjust = 0),
    plot.margin = margin(10, 10, 10, 0)
  ) +
  guides(
    size = "none",
    color = guide_colorbar(
      title = "Segment length (in words)",
      title.position = "top",
      direction = "horizontal",
      barwidth = unit(12, "cm"),
      barheight = unit(0.2, "cm")
    )
  )
ggsave("data/graphs/LWT_pauses.jpg", width = 7.2, height = 5, dpi = 300)


# Correlations ------------------------------------------------------------











alignments |> 
  ungroup() |>
  filter(syl_per_sec < 20) |> #View()
  ggplot(aes(x = factor(season), y = syl_per_sec)) +
  geom_boxplot() +
  labs(
    x = "Season",
    y = "Syllables per second",
    title = "Speech rate by season"
  ) +
  theme_minimal()

# For wpm on episodes:
episodes <- episodes |> 
  mutate(viewers_m = viewers * 1000000,
         wpm = wrds/length * 60,
         spm = syls/length,
         vlr = likes/views,
         vcr = comms/views)

## TV viewers per episode
episodes |> 
  select(ytdate, ep_id, season, viewers_m) |> 
  ggplot(aes(ytdate, viewers_m)) +
  geom_point(aes(color = as.factor(season))) +
  geom_smooth(method = 'loess') +
  labs(title = 'Last Week Tonight: Popularity',
       subtitle = 'TV viewer rise and decline',
       x = 'Year',
       y = 'TV viewers (millions)') +
  scale_x_date(date_breaks = '1 year', date_labels = "%Y") +
  guides(colour = guide_legend(nrow = 1))

## Online viewers per episode
episodes |> 
  select(ytdate, ep_id, season, views) |> 
  ggplot(aes(ytdate, views)) +
  geom_point(aes(color = season)) +
  #geom_line(group = 1) +
  geom_smooth(method = 'loess') +
  labs(title = 'Last Week Tonight: Popularity',
       subtitle = 'Online viewer decline',
       x = 'Year',
       y = 'Online viewers (millions)') +
  scale_x_date(date_breaks = '1 year', date_labels = "%Y") +
  guides(colour = guide_legend(nrow = 1))

## TV vs. online views
tv_vs_online1 <- episodes |> 
  select(ytdate, ep_id, season, views, viewers_m) |> 
  ggplot(aes(views, viewers_m)) +
  geom_point() +
  #geom_line(group = 1) +
  geom_smooth(method = 'loess') +
  labs(title = 'Last Week Tonight: Popularity',
       subtitle = 'TV vs. online views',
       x = 'Online viewers',
       y = 'TV viewers')
tv_vs_online2 <- episodes |> 
  select(ytdate, ep_id, season, views, viewers_m) |> 
  ggplot(aes(views, viewers_m, color = season)) +
  geom_point() +
  #geom_line(group = 1) +
  geom_smooth(method = 'lm', se = F) +
  labs(title = 'Last Week Tonight: Popularity',
       subtitle = 'TV vs. online views by season',
       x = 'Online viewers',
       y = 'TV viewers') +
  guides(colour = guide_legend(nrow = 1))
tv_vs_online1 + tv_vs_online2


## Words per minute per episode
episodes |> 
  filter(!is.na(wpm)) |> 
  group_by(season) |> 
  summarise(median(wpm), median(length))

episodes |> 
  filter(!(is.na(wpm))) |> 
  select(wpm, ytdate, wrds, length) |> 
  ggplot(aes(
    x = ytdate,
    y = wpm,
    color = length,
    #size = length
  )) +
  geom_point(alpha = 1, size = 2) +
  scale_color_viridis_c(option = "viridis") +
  scale_size_continuous(trans = "log10") +
  labs(
    title = "Last Week Tonight: Faster and faster!",
    subtitle = "John Oliver's speaking pace has increased from 150 wpm to almost 180 wpm",
    x = '',
    y = 'Words per minute (average by episode)',
    caption = 'Based on subtitle files — outliers due to a faulty subtitle file.'
  ) +
  scale_x_date(date_breaks = '1 year', date_labels = "%Y") +
  hrbrthemes::theme_ipsum_gs() +
  theme(
    legend.position = "top",
    legend.direction = "horizontal"
  ) +
  guides(
    size = "none",
    color = guide_colorbar(
      title = "Segment length (in words)",
      title.position = "top",
      direction = "horizontal",
      barwidth = unit(10, "cm"),
      barheight = unit(0.2, "cm")
    )
  )

# ...do the same with the summs per season:
episodes |> 
  group_by(season) |> 
  summarise(wpm_mean = mean(wpm, na.rm = TRUE),
            seg_len_mean = mean(duration/60, na.rm = TRUE)) |> 
  ggplot(aes(season, wpm_mean, color = season)) +
  geom_line(group = 1) +
  geom_point(aes(size = log(as.numeric(seg_len_mean)))) +
  labs(title = 'Last Week Tonight: words per minute over time',
       subtitle = 'John Oliver has become increasingly fast-paced',
       x = 'Season',
       y = 'Words per minute (mean by episode)',
  ) +
  theme(legend.position = 'none')

## So amount of data is increasing, while segments becoming longer, is the
## the higher **related** to segment length?
ep_scaled <- episodes |> 
  # select variables
  select(season, episode_season, duration, viewers, length, views, likes, comms, syls, wrds, wpm, spm, vlr, vcr) |> 
  # and scale them
  mutate_at(vars(viewers:vlr), datawizard::rescale)

m1 <- lm(wpm_mean ~ seg_length + season, data = alignments_summ)
summary(m1)
performance::check_model(m1)
jtools::plot_coefs(m1)

wpm1 <- alignments_summ |> 
  ggplot(aes(seg_length, wpm_mean)) +
  geom_point() +
  #geom_smooth(se = F) +
  labs(title = 'Words per minute by segment length',
       subtitle = 'Positive relationship: Longer segments have a higher pace...',
       x = 'Segment length in minutes',
       y = 'Words per minute')

wpm2 <- alignments_summ |> 
  ggplot(aes(seg_length, wpm_mean, color = season)) +
  geom_point() +
  geom_smooth(se = F, method = 'lm') +
  labs(title = ' ',
       subtitle = '...they actually don\'t if controlled by season.',
       x = 'Segment length in minutes',
       y = ' ') +
  theme(legend.position = 'right')

wpm1 + wpm2

ep_scaled |> 
  ggplot(aes(length, wpm)) +
  geom_point() +
  geom_smooth(se = F, method = 'lm')

# is poplarity (vlr) related to views/seasons?
## visualize predictors:
dat |> 
  ggplot(aes(views, vlr, color = season)) +
  geom_point() +
  geom_smooth(method = 'lm', se = F) #+
facet_wrap(~season)

m1 <- lm(viewers~vlr, data = ep_scaled)
summary(m1)

## Words per minute per episode
alignments_summ |> 
  filter(!ytid %in% c('dykZyuWci3g')) |> 
  ggplot(aes(ytdate, wpm_mean, color = season)) +
  geom_line(group = 1, col = 'grey96', linewidth = 0.5) +
  geom_point() +
  #geom_smooth(method = 'lm', se = F)
  labs(title = 'Last Week Tonight: words per minute over time',
       subtitle = 'John Oliver has become increasingly fast-paced',
       x = 'Year',
       y = 'Words per minute',
       caption = 'Based on number of words per minute per subtitle file.') +
  scale_x_date(date_breaks = '1 year', date_labels = "%Y") +
  suzR::theme_suzR() +
  guides(colour = guide_legend(nrow = 1)) +
  theme(legend.position = 'none')

## Words per minute per episode
alignments_summ |> 
  filter(!ytid %in% c('dykZyuWci3g')) |> 
  ungroup(season) |> 
  ggplot(aes(ytdate, roll_mean)) +
  geom_line(col = 'grey96') +
  geom_point() +
  geom_smooth(method = 'lm', se = F) +
  labs(title = 'Last Week Tonight: syllables per minute over time',
       subtitle = 'John Oliver has become increasingly fast-paced',
       x = 'Year',
       y = 'Syllables per second (rolling mean across 5 words)',
       caption = 'Words with short duration than 200ms removed.') +
  scale_x_date(date_breaks = '1 year', date_labels = "%Y") +
  suzR::theme_suzR() +
  guides(colour = guide_legend(nrow = 1)) +
  theme(legend.position = 'none')

## Pauses between words episode
alignments_summ |> 
  filter(!ytid %in% c('dykZyuWci3g')) |>
  ggplot(aes(ytdate, pause_mean, color = season)) +
  geom_line(group = 1, col = 'grey96') +
  geom_point() +
  #geom_smooth(method = 'lm', se = F)
  labs(title = 'Last Week Tonight: pauses between words over time',
       subtitle = 'John Oliver has become increasingly fast-paced',
       x = 'Year',
       y = 'Syllables per second (rolling mean across 5 words)',
       caption = 'Words with short duration than 200ms removed.') +
  scale_x_date(date_breaks = '1 year', date_labels = "%Y") +
  suzR::theme_suzR() +
  guides(colour = guide_legend(nrow = 1)) +
  theme(legend.position = 'none')
alignments_summ |> 
  #filter(john == 'y') |> 
  ggplot(aes(ep_id, dur_paus_ratio)) +
  geom_line(group = 1) +
  geom_point() +
  labs(title = 'Duration to pause ratio')

alignments_summ |> 
  #filter(john == 'y') |> 
  ggplot(aes(ep_id, align_errors)) +
  geom_line(group = 1) +
  geom_point() +
  labs(title = 'Proportion of non-recognized words') 

# Sandbox -----------------------------------------------------------------

dat <- episodes |> 
  mutate(wpm = wrds/length * 60,
         spm = syls/length,
         vlr = likes/views,
         vcr = comms/views)

## viewers over time:
views1 <- dat |> 
  ggplot(aes(views, viewers)) +
  geom_point() +
  geom_smooth(se = F) +
  labs(title = 'Last Week Tonight viewership',
       subtitle = 'TV ratings vs. online views',
       x = 'online views',
       y = 'TV viewers') +
  #facet_wrap(~season) +
  suzR::theme_suzR()
views1

views2 <- dat |> 
  ggplot(aes(views, viewers, color = season)) +
  geom_point() +
  geom_smooth(method = 'lm', se = F) +
  labs(title = 'Last Week Tonight viewership',
       subtitle = 'TV ratings vs. online views',
       x = 'online views',
       y = 'TV viewers') +
  #facet_wrap(~season) +
  suzR::theme_suzR() +
  guides(colour = guide_legend(nrow = 1))

views2



# outliers:
subs_list["Nn_Zln_4pA8"]

dat |> 
  ggplot(aes(ytdate, duration, group = season, color = season)) +
  geom_line() +
  geom_point() +
  labs(title = 'Last Week Tonight: segment duration over time',
       subtitle = 'John Oliver uploads longer segments to YT',
       x = 'Year',
       y = 'Duration of segments') +
  scale_x_date(date_breaks = '1 year', date_labels = "%Y") +
  suzR::theme_suzR() +
  guides(colour = guide_legend(nrow = 1))

## visualize predictors:
dat |> 
  ggplot(aes(viewers)) +
  geom_histogram()

