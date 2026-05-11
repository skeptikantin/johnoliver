# John Oliver's speech rate over time


## Data source, processing & availability

* source
  - audio tracks & auto-generated subtitle files from [Last Week Tonight's YouTube channel](https://www.youtube.com/lastweektonight).
  - download using [yt-dlp](https://github.com/yt-dlp/yt-dlp)
* annotation
  - word-level alignments with [Gentle](https://github.com/strob/gentle)
  - word duration measures
* data/
  - episodes.csv
  - alignments.csv
  
## Data structure

### episodes.csv

column|description
---|-----
`season`|Season of show
`episode_total`|Running number of episode since show began
`episode_season`|Number of episode within the season
`ep_id`|Episode ID (format: Season_Episode)
`main_segment`|Title of main show segment (used in analysis)
`air_date`|Date of broadcast

  
## Analysis

See the Github page
