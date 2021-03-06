library(tidyverse)
library(gt)
library(future)
library(ggtext)
library(ggpmisc)
library(DescTools)

source('R/helpers.R')
source("https://raw.githubusercontent.com/mrcaseb/nflfastR/master/R/helper_add_nflscrapr_mutations.R")
source('R/season_numbers_functions.R')

# **************************************************************************************
# the first part: numbers for one season only (2020 here)
# get list of plays

# new addition 18 dec 2020: current season function which saves calculations that have been done already
# so if you run this one week and again the next week, it will only have to do calculations for the new games
# do not use this function with older seasons, use get_season as shown below
# or just load the data i already provide in this repo
cleaned <- get_current_season(2020)

# **************************************************************************************
# decision-making table

# this is just for table titles now
s = 2020

t <- cleaned %>%
  filter(
    play_type != "PENALTY"
    # go_boost > 1 | go_boost < -1
  ) %>%
  mutate(type = case_when(
    go_boost >= 4 ~ "Definitely go for it",
    go_boost > 1 & go_boost < 4 ~ "Probably go for it",
    go_boost >= -1 & go_boost <= 1 ~ "Toss-up",
    go_boost < -1 & go_boost > -4 ~ "Probably kick",
    go_boost <= -4 ~ "Definitely kick"
  )) %>%
  group_by(type) %>%
  summarize(go = mean(go), n = n()) %>%
  ungroup() %>%
  arrange(-go) %>%
  mutate(go = 100 * go) %>%
  gt() %>%
  cols_label(
    type = "Recommendation",
    go = "Went for it %",
    n = "Plays"
  ) %>%
  tab_style(
    style = cell_text(color = "black", weight = "bold"),
    locations = list(
      cells_row_groups(),
      cells_column_labels(everything())
    )
  ) %>% 
  tab_options(
    row_group.border.top.width = px(3),
    row_group.border.top.color = "black",
    row_group.border.bottom.color = "black",
    table_body.hlines.color = "white",
    table.border.top.color = "black",
    table.border.top.width = px(1),
    table.border.bottom.color = "white",
    table.border.bottom.width = px(1),
    column_labels.border.bottom.color = "black",
    column_labels.border.bottom.width = px(2)
  ) %>%
  fmt_number(
    columns = vars(go), decimals = 0
  ) %>%
  cols_align(
    columns = 2:3,
    align = "center"
  ) %>% 
  tab_header(
    title = md(glue::glue("NFL team decision-making by go recommendation, 2020"))
  ) %>%
  tab_source_note(md('**Notes**: "Definitely" recommendations are greater than 4 percentage point advantage,<br> "probably" 1-4 percentage points'))


t

t %>% gtsave("figures/team_behavior.png")

# **************************************************************************************
# worst decisions table

t <- cleaned %>%
  filter(
    play_type != "PENALTY",
    go == 0
  ) %>%
  mutate(
    defteam = if_else(posteam == home_team, away_team, home_team)
  ) %>%
  arrange(-go_boost) %>%
  head(5) %>%
  select(posteam, defteam, week, qtr, ydstogo, go_boost, desc) %>%
  gt() %>%
  cols_label(
    posteam = "Team",
    defteam = "Opp.",
    week = "Week",
    qtr = "Qtr",
    ydstogo = "Yds to go",
    desc = "Play",
    go_boost = "Go gain (%)"
  ) %>%
  tab_style(
    style = cell_text(color = "black", weight = "bold"),
    locations = list(
      cells_row_groups(),
      cells_column_labels(everything())
    )
  ) %>% 
  tab_options(
    row_group.border.top.width = px(3),
    row_group.border.top.color = "black",
    row_group.border.bottom.color = "black",
    table_body.hlines.color = "white",
    table.border.top.color = "black",
    table.border.top.width = px(1),
    table.border.bottom.color = "white",
    table.border.bottom.width = px(1),
    column_labels.border.bottom.color = "black",
    column_labels.border.bottom.width = px(2)
    
  ) %>%
  fmt_number(
    columns = vars(go_boost), decimals = 1
  ) %>%
  cols_align(
    columns = 1:5,
    align = "center"
  ) %>% 
  tab_header(
    title = md(glue::glue("Worst kick decisions of 2020"))
  )

t

t %>% gtsave("figures/team_worst.png")

# take a look at the worst decisions
cleaned %>%
  filter(
    play_type != "PENALTY",
    go == 0
  ) %>%
  mutate(
    defteam = if_else(posteam == home_team, away_team, home_team)
  ) %>%
  arrange(-go_boost) %>%
  head(5) %>% 
  select(game_id, url, go_boost, desc)


# **************************************************************************************
# league behavior by co recommendation

my_title <- glue::glue("NFL Go-for-it Rate on <span style='color:red'>4th down</span>")
plot <- cleaned %>%
  # filter(prior_wp > .05 & prior_wp < .95) %>%
  mutate(go_boost = RoundTo(go_boost, 0.5)) %>%
  group_by(go_boost) %>%
  summarize(go = 100 * mean(go)) %>%
  ungroup() %>%
  filter(between(go_boost, -10, 10)) %>%
  mutate(
    should_go = case_when(go_boost > .5 ~ 1,
                          go_boost < -.5 ~ 0,
                          TRUE ~ 2)
  )

plot %>%
  ggplot(aes(go_boost, go, color = as.factor(should_go))) + 
  geom_point(size = 5, color = "black", alpha = .5) +
  geom_vline(xintercept = 0)+
  geom_smooth(method = "lm", show.legend = F, se = F, size = 3)+
  theme_bw()+
  labs(x = "Gain in win probability by going for it",
       y = "Go-for-it percentage",
       caption = paste0("Figure: @benbbaldwin"),
       subtitle = "By strength of @ben_bot_baldwin recommendation, 2020",
       title = my_title) +
  theme(
    legend.position = "none",
    plot.title = element_markdown(size = 22, hjust = 0.5),
    plot.subtitle = element_markdown(size = 12, hjust = 0.5)
  ) +
  scale_y_continuous(breaks = scales::pretty_breaks(n = 10)) +
  scale_x_continuous(breaks = scales::pretty_breaks(n = 20), limits = c(-10, 10), expand = c(0,0)) +
  annotate("text",x=-4, y= 90, label = "Should\nkick", color="red", size = 7) +
  annotate("text",x=3, y= 90, label = "Should\ngo for it", color="red", size = 7) +
  annotate("label",x=-6, y= 15, label = "Teams almost always kick\nwhen they should...", size = 6) +
  annotate("label",x=6, y= 25, label = "...but frequently\n kick when they\nshould go for it", size = 6)
  
ggsave("figures/league_behavior.png")

# ###########
# go by WP
my_title <- glue::glue("NFL Go-for-it Rate on <span style='color:red'>4th down</span>")
plot <- cleaned %>%
  filter(go_boost > 2) %>%
  mutate(wp = round(100 * prior_wp, 0)) %>%
  group_by(wp) %>%
  summarize(go = 100 * mean(go), n = n()) %>%
  ungroup()

cleaned %>%
  filter(go_boost > 2) %>%
  mutate(prior_wp = 100 * prior_wp) %>%
  ggplot(aes(prior_wp, go)) + 
  # geom_point(size = 5, color = "black", alpha = .5) +
  geom_smooth(show.legend = F, se = F, size = 3, color = "black")+
  theme_bw()+
  labs(x = "Win probability prior to play",
       y = "Go-for-it percentage",
       caption = paste0("Figure: @benbbaldwin"),
       subtitle = "@ben_bot_baldwin gain in win prob by going for it > 2 percentage points",
       title = my_title) +
  theme(
    legend.position = "none",
    plot.title = element_markdown(size = 22, hjust = 0.5),
    plot.subtitle = element_markdown(size = 12, hjust = 0.5)
  ) +
  scale_y_continuous(breaks = scales::pretty_breaks(n = 10), limits = c(0, 1)) +
  scale_x_continuous(breaks = scales::pretty_breaks(n = 20)) 

ggsave("figures/league_behavior_wp.png")

# ###################################################### #######################
# ############## team bar chart
current <- cleaned %>%
  filter(go_boost > 1.5) %>%
  filter(prior_wp > .2) %>%
  group_by(posteam) %>%
  summarize(go = mean(go), n = n()) %>%
  ungroup() %>%
  left_join(nflfastR::teams_colors_logos, by=c('posteam' = 'team_abbr')) %>%
  arrange(-go) %>%
  mutate(rank = 1:n()) %>%
  arrange(posteam)


ids <- nflfastR::teams_colors_logos %>%
  filter(!team_abbr %in% c('LAR', 'OAK', 'SD', 'STL'))
images <- magick::image_read(ids%>% pull(team_logo_espn)) 

logos <- tibble(
  x = current$rank + .25, 
  y = current$go + .02,
  width = .035,
  grob = 
    map(1:32, function(x) {
      grid::rasterGrob(images[x])
    })
)

my_title <- glue::glue("Which teams <span style='color:red'>go for it</span> when they <span style='color:red'>should?</span> {s}")
ggplot(data = current, aes(x = reorder(posteam, -go), y = go)) +
  geom_col(data = current, aes(fill = ifelse(posteam=="SEA", team_color2, team_color)), 
           width = 0.5, alpha = .6, show.legend = FALSE
  ) +
  geom_grob(data = logos, 
            aes(x, y, label = grob, vp.width = width),
            hjust = 0.7) +
  scale_fill_identity(aesthetics = c("fill", "colour")) +
  theme_bw() +
  theme(
    panel.grid.major.x = element_blank(),
    plot.title = element_markdown(size=22,face = 2,hjust=.5),
    plot.subtitle = element_text(size=8, hjust=.5),
    axis.title.x=element_blank(),
    axis.text.x=element_blank(),
    axis.ticks.x=element_blank()
    ) +
  # scale_y_continuous(expand=c(0,0), limits=c(0, max(current$go + 5))) +
  scale_y_continuous(breaks = scales::pretty_breaks(n = 10)) +
  labs(
    x = "",
    y = "Go rate",
    title= my_title,
    subtitle = "When @ben_bot_baldwin recommends going for it (gain in win prob. at least 1.5 percentage points)",
    caption = glue::glue("Sample size in parentheses\nExcl. final 30 seconds of game. Win prob >20%")
  ) +
  geom_text(data = current, aes(x = rank, y = -.015, size=.04, label = glue::glue("({n})")), show.legend = FALSE, nudge_x = 0, color="black")

ggsave(glue::glue("figures/teams_{s}.png"))


# total WP lost
current <- cleaned %>%
  filter(go_boost > 0, go == 0) %>%
  group_by(posteam) %>%
  summarize(go = sum(go_boost), n = n()) %>%
  ungroup() %>%
  left_join(nflfastR::teams_colors_logos, by=c('posteam' = 'team_abbr')) %>%
  arrange(-go) %>%
  mutate(rank = 1:n()) %>%
  arrange(posteam)

logos <- tibble(
  x = current$rank + .25, 
  y = current$go + .02,
  width = .035,
  grob = 
    map(1:32, function(x) {
      grid::rasterGrob(images[x])
    })
)

my_title <- glue::glue("Expected win probability <span style='color:red'>lost by kicking in go situations</span>, {s}")
ggplot(data = current, aes(x = reorder(posteam, -go), y = go)) +
  geom_col(data = current, aes(fill = ifelse(posteam=="SEA", team_color2, team_color)), 
           width = 0.5, alpha = .6, show.legend = FALSE
  ) +
  geom_grob(data = logos, 
            aes(x, y, label = grob, vp.width = width),
            hjust = 0.7) +
  scale_fill_identity(aesthetics = c("fill", "colour")) +
  theme_bw() +
  theme(
    panel.grid.major.x = element_blank(),
    plot.title = element_markdown(size=22,face = 2,hjust=.5),
    plot.subtitle = element_text(size=8, hjust=.5),
    axis.title.x=element_blank(),
    axis.text.x=element_blank(),
    axis.ticks.x=element_blank()
  ) +
  # scale_y_continuous(expand=c(0,0), limits=c(0, max(current$go + 5))) +
  scale_y_continuous(n.breaks = 10) +
  labs(
    x = "",
    y = "Win probability lost",
    title= my_title,
    caption = glue::glue("@benbbaldwin | Excl. final 30 seconds of game")
  )

ggsave(glue::glue("figures/teams_lost_{s}.png"))



# **************************************************************************************
# the second part: numbers for every season

# get old season numbers if they aren't there already
if (!file.exists("data/prior_season_decisions.rds")) {
  
  # this will take a very long time
  cleaned_old <- map_df(2014:2019, function(x) {
    message(glue::glue("Getting season {x}. . ."))
    get_season(x)
  })
  
  saveRDS(cleaned_old, file = "data/prior_season_decisions.rds")
  
}

# bind 2020 data to the prior season data
cleaned_all <- bind_rows(
  cleaned,
  readRDS("data/prior_season_decisions.rds")
)


# team over time
current <- cleaned_all %>%
  mutate(
    season = substr(game_id, 1, 4) %>% as.numeric()
  ) %>%
  filter(go_boost > 1.5) %>%
  filter(prior_wp > .2) %>%
  group_by(posteam, season) %>%
  summarize(go = mean(go), n = n()) %>%
  ungroup() %>%
  left_join(nflfastR::teams_colors_logos, by=c('posteam' = 'team_abbr')) %>%
  arrange(-go) %>%
  mutate(rank = 1:n()) %>%
  arrange(posteam, season)

means <- current %>%
  group_by(season) %>%
  summarize(league_go = mean(go)) %>%
  ungroup()

# function to make team timeline
make_timeline <- function(team) {
  
  prim <- nflfastR::teams_colors_logos %>% filter(team_abbr == team) %>% pull(team_color)
  sec <- nflfastR::teams_colors_logos %>% filter(team_abbr == team) %>% pull(team_color2)
  name <- nflfastR::teams_colors_logos %>% filter(team_abbr == team) %>% pull(team_nick)
  
  chart <- current %>%
    filter(posteam==team)
  teams <- current %>%
    filter(posteam != team)
  
  ### pass downs over time
  my_title <- glue::glue("How often do the <span style='color:red'>{name}</span> go for it when they <span style='color:red'>should?</span>")
  fig <- ggplot(data=chart, aes(x=season,y=go)) +
    geom_line(data=chart,
              aes(x=season,y=go),color=prim,size=3) +
    geom_point(data=chart,
               aes(x=season,y=go),color=sec,size=8) +
    geom_line(data=means,
              aes(x=season,y=league_go),color="black",size=1, linetype="dashed", alpha=.6) +
    geom_jitter(data=teams,
                aes(x=season,y=go), color=teams$team_color, size=4, alpha=.6, width = .045) +
    labs(
      x = "",
      y = "Go rate",
      title= my_title,
      subtitle = "When @ben_bot_baldwin recommends going for it (gain in win prob. at least 1.5 percentage points)",
      caption = glue::glue("Excl. final 30 seconds of game. Win prob >20%")
    ) +
    scale_x_continuous(breaks=c(min(chart$season):max(chart$season))) +
    scale_y_continuous(breaks = scales::pretty_breaks(n = 10)) +
    theme_bw()+
    theme(axis.title.x = element_blank(),
          axis.title.y = element_text(size = 18),
          panel.grid.minor.x = element_blank(),
          axis.text.x = element_text(size=16),
          axis.text.y = element_text(size=16),
          plot.title = element_markdown(size=24,face = 2,hjust=.5),
          plot.subtitle = element_text(size=12, hjust=.5))
  
  
  ggsave(glue::glue("figures/team_timelines/teams_timeline_{team}.png"), plot = fig)
  
  return(fig)
  
}

make_timeline("NO")


