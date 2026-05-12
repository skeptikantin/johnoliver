# John Oliver's speech rate over time

Data & analysis of changes in John Oliver's speech rate over time.

Based on 314 episodes by the end of Season 11 (2024), and the main segments ("main story") that are available on the show's YouTube channel.

See the [write-up](https://skeptikantin.github.io/johnoliver/).

## Data source, processing & availability

I'm yet to update the full documentation of the scraping and cleaning process. The raw data is basically a bunch of text and audio files. The audio files cannot be provided for legal reasons and space limitations. The closed-caption/transcript files are already included in the file `alignments.csv` described below, and result from the horizontal, one-word-per-line output of Gentle.

- source
  - list of [Last Week Tonight episodes](https://en.wikipedia.org/wiki/List_of_Last_Week_Tonight_with_John_Oliver_episodes) & main segments
  - audio tracks & auto-generated subtitle files from [Last Week Tonight's YouTube channel](https://www.youtube.com/lastweektonight).
  - download using [yt-dlp](https://github.com/yt-dlp/yt-dlp)
- annotation
  - word-level alignments with [Gentle](https://github.com/strob/gentle)
  - word duration measures
- data/
  - episodes.csv
  - alignments.csv

## Data structure

### episodes.csv

314 episodes

| column | description |
|:-----------------------------------|:-----------------------------------|
| `season` | Season of show |
| `episode_total` | Running number of episode since show began |
| `episode_season` | Number of episode within the season |
| `ep_id` | Episode ID (format: Season_Episode) |
| `main_segment` | Title of main show segment (used in analysis) |
| `air_date` | Date of broadcast |
| `viewers` | TV viewers (in millions) |
| `period` | pre-covid, covid, post-covid (shows labelled 'covid' broadcast from "blank white void full of sad facts") |
| `ytid` | YouTube ID of segment |
| `youtube_link` | Link to segment on YouTube |
| `aligned` | Whether episode was aligned with Gentle |
| `checked` | Has it been manually checked |
| `subs` | Remark on subtitles |
| `ytdate` | Date of upload to YouTube |
| `length` | Length of segment (in seconds) |
| `views` | YouTube views (at the day of download in October 2024) |
| `likes` | YouTube likes (at the day of download in October 2024) |
| `comms` | YouTube comments (at the day of download in October 2024) |
| `duration` | Duration of segment (hh:mm:ss) |
| `syls` | Total number of syllables |
| `wrds` | Total number of words |

### alignments.csv

376,296 words from 108 randomly chosen segments that were forced-aligned with Gentle.

| column          | type | description                                         |
|:----------------|:-----|:----------------------------------------------------|
| `ytid`          | chr  | ID of YouTube video                                 |
| `season`        | num  | Season of episode                                   |
| `episode_seaon` | num  | Number of episode within the season                 |
| `ep_id`         | chr  | Episode ID (format: Season_Episode)                 |
| `ytdate`        | date | Date of upload                                      |
| `word`          | chr  | Word                                                |
| `recog`         | chr  | Word recognised by Gentle                           |
| `beg`           | num  | Beginning of word (in second from start of segment) |
| `end`           | num  | End of word (in seconds from start of segment)      |

## To do

- Upload the cleaning/processing script
- Clean-up the variable names to be more consistent
