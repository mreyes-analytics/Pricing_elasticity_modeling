library(tidyverse)
library(broom)
library(scales)

# 1. Load dummy data ----
dummy_data <- read_csv("data/cement_dummy_data.csv",
                       show_col_types = FALSE)

glimpse(dummy_data)

# 2. Aggregate by SEGMENT & MONTH ----
datos_segment <- dummy_data %>%
  group_by(SEGMENT, MES) %>%
  summarise(
    PRICE_AVG   = weighted.mean(PRECIO_VTA, BULTOS),
    TOTAL_UNITS = sum(BULTOS),
    TOTAL_SALES = sum(VENTAS),
    .groups = "drop"
  )

# Quick sanity check
datos_segment %>%
  arrange(SEGMENT, MES) %>%
  print(n = 10)

# 3. Log–log elasticity model per segment ----
elasticity_results <- datos_segment %>%
  group_by(SEGMENT) %>%
  group_modify(~{
    modelo <- lm(log(TOTAL_UNITS) ~ log(PRICE_AVG), data = .x)
    s      <- summary(modelo)
    
    tibble(
      n_observations = nrow(.x),
      elasticity     = unname(coef(modelo)[2]),
      std_error      = s$coefficients[2, 2],
      p_value        = s$coefficients[2, 4],
      r_squared      = s$r.squared
    )
  }) %>%
  ungroup() %>%
  mutate(
    elasticity      = round(elasticity, 3),
    std_error       = round(std_error, 3),
    p_value         = round(p_value, 4),
    r_squared       = round(r_squared, 3),
    abs_elasticity  = abs(elasticity),
    significance    = case_when(
      p_value < 0.05 ~ "Significant (p < 0.05)",
      p_value < 0.10 ~ "Marginal (p < 0.10)",
      TRUE           ~ "Not significant"
    )
  )

print(elasticity_results)

# 4. Ensure outputs dir exists ----
dir.create("outputs", showWarnings = FALSE)

# 5. Plot 1: Elasticity by segment ----
p_elasticity <- elasticity_results %>%
  ggplot(aes(x = reorder(SEGMENT, -abs_elasticity),
             y = abs_elasticity,
             fill = SEGMENT)) +
  geom_col(width = 0.6, show.legend = FALSE) +
  geom_text(aes(label = elasticity),
            vjust = -0.6, size = 4.5, fontface = "bold") +
  labs(
    title = "Price Elasticity by Segment (absolute value)",
    x = NULL,
    y = "Elasticity (|β_price|)"
  ) +
  theme_minimal(base_size = 13)

ggsave("outputs/elasticity_by_segment.png",
       p_elasticity, width = 8, height = 5, dpi = 150, bg = "white")

# 6. Plot 2: Price–demand scatter with linear fit ----
p_scatter <- datos_segment %>%
  ggplot(aes(x = PRICE_AVG,
             y = TOTAL_UNITS,
             color = SEGMENT)) +
  geom_point(alpha = 0.7, size = 2.8) +
  geom_smooth(method = "lm", se = TRUE, linewidth = 1, alpha = 0.2) +
  scale_y_continuous(labels = comma) +
  scale_x_continuous(labels = dollar) +
  labs(
    title  = "Price vs. Demand by Segment",
    x      = "Average Price ($/unit)",
    y      = "Units Sold (monthly)",
    color  = "Segment"
  ) +
  theme_minimal(base_size = 13) +
  theme(
    legend.position = "bottom",
    panel.grid.minor = element_blank()
  )

ggsave("outputs/price_demand_scatter.png",
       p_scatter, width = 8, height = 5, dpi = 150, bg = "white")

# 7. (Optional) Conceptual elasticity graphic ----
elasticity_concept <- tibble(
  Type    = factor(c("Inelastic", "Moderate", "Highly Elastic"),
                   levels = c("Inelastic", "Moderate", "Highly Elastic")),
  Value   = c(0.5, 2.0, 5.0),
  Label   = c(
    "↑1% price → ↓0.5% demand",
    "↑1% price → ↓2% demand",
    "↑1% price → ↓5% demand"
  )
)

p_concept <- elasticity_concept %>%
  ggplot(aes(x = Type, y = Value, fill = Type)) +
  geom_col(width = 0.6, show.legend = FALSE) +
  geom_text(aes(label = Label),
            vjust = -0.6, size = 3.8, fontface = "bold") +
  labs(
    title = "Conceptual View of Price Elasticity",
    x = NULL,
    y = "Elasticity (|β|)"
  ) +
  theme_minimal(base_size = 13)

ggsave("outputs/elasticity_concept.png",
       p_concept, width = 7, height = 5, dpi = 150, bg = "white")

message("Done. Results table printed and plots saved to /outputs.")
