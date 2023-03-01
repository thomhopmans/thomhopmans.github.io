---
layout: post
title: The GAM approach to spend your money more efficiently!
date: 2015-09-15 12:00:00 +0100
categories: data-science R generalized-additive-models marketing
author: Thom Hopmans
---

In an <a href="">earlier blogpost</a> we described how Blue Mango Interactive optimizes the media spend of clients using S-curves. S-curves are used to find the S-shaped relationship of a particular media driver on a KPI such as sales. Moreover, when a S-curve is obtained, we can determine the optimal point that prevents under- or overspending. Hence, we spend our money more efficiently! The previous method however required quite some manual steps and hassle. Inspired by an awesome blogpost (<a href="http://multithreaded.stitchfix.com/blog/2015/07/30/gam/" target="_blank">GAM: The Predictive Modeling Silver Bullet</a>) we return this time with a brand new state-of-the art modelling technique: **GAM!**

<img alt="Example of a S-shaped response curve for the effect of radio on sales" />

The previous blog post described how an ordinary least-squares (OLS) regression can be used to find the S-curve of a particular media driver. In a fictional example we estimated the S-curve for radio in terms of <a href="https://en.wikipedia.org/wiki/Gross_rating_point" target="_blank">GRPs</a>. The OLS regression technique comes from the family of generalized linear modelling (<a href="https://en.wikipedia.org/wiki/Generalized_linear_model" target="_blank">GLM</a>) techniques. One of the reasons GLM techniques are so popular nowadays is that they provide an interpretable and computationally fast method to find the effect of independent variables (e.g. years of education, age) on a dependent variable (e.g. wage). For example, an OLS regression could return that the relationship between education and wage is that for every year of education followed you’ll earn €500 p/m more. Adding more variables to this OLS regression such as age and gender will result in their quantified effects on wage.

## The L is for linear relationships

Unfortunately, as the name already suggests, OLS typically only returns linear relationships between the independent variables (e.g. years of education) and dependent variable (e.g. wage). Using the previous wage example, one year of education would imply earning €500 p/m, but ten years of education would imply earning €5000 p/m. Linear relationships are however very limited when modelling nonlinear relationships. For example, assume that the first year of education results in earning €500 p/m more, but the second year only gives you €400 more on top of that, and the third year €300, and so on... If the marginal effect of every additional year of education is decreasing like this, then a really worse fit is obtained when using OLS.
In practice, such non-linear relationships are often tackled by applying transformations on the data. For example, it is possible to capture the diminishing effect of each additional year of education by applying a square root on the years of education. Assuming that after a square root transformation on education the quantified relationship between education and wage is still €500, then ten years of education would imply earning $$ \sqrt(10) = 3.16 × 500 = 1550 $$ euro p/m.

## I’ve got 99 problems and linear relationships ain’t one

So, what is the problem if data transformations can be used to model non-linear relationships using GLM techniques? Well, in most cases, we have to perform many OLS regressions to find the best-fitting data transformation. This process involves trying a lot of different transformations. For example, we need to check whether the transformation $$ x^{0.4} $$ fits the data better than $$ x^{0.6} $$ or $$ x^{0.5} $$. Moreover, we might be overfitting our data. It could be that the true relationship is y=x0.5, but that y=x0.54 fits our random sample dataset better. Preferably, we need some a priori knowledge about the type of transformation we need.

In the previous blog post we described a method that finds the S-response curve of a media driver in several steps. Assume that we want to estimate the S-shaped effect of radio GRPs. This required the following steps:

1. The continuous radio GRP variable was replaced by dummies, each representing a specific continuous interval.
2. An OLS regression was used to estimate the effect of each dummy and thus of each interval.
3. A S-curve was then estimated that fits with the estimated effects of each interval.
4. A S-curve transformation was then applied to transform the continuous radio variable.
5. Finally, the OLS regression was performed again. This time however, the transformed continuous radio variable was used instead of the interval dummies. Because the radio variable is transformed, the coefficient returned by the OLS regression now didn’t denote a linear relationship anymore, but a S-shaped relationship.
Wouldn’t it be nice if we could skip all these (manual) steps and use a more mathematical approach to find the best-fitting S-curve? **GAM modelling to the rescue!**

<img alt="GAM modelling to the rescue (Photo by Coast Guard News on Flickr)">

## GAM modelling to the rescue!

Generalized additive models (GAM) is an additive modelling technique where the effect of the dependent variables (e.g. wage) is captured through smooth functions on the independent variables (e.g. years of education, age, gender). Note that these smooth functions do not need to be linear as is the case in GLMs! An example of variables in a GAM model is given below, where $$ s_1 $$ and $$ s_2 $$ are smooth non-linear functions with respective input $$ x_1 $$ and $$ x_2 $$ . Note that $$ s_3 $$ is a smooth linear function as is normally returned by OLS.

<img alt="Example of flexible smooth (non-)linear functions" />

GAM models therefore have the same easy and intuitive interpretation property of OLS models, but also have the flexibility to model nonlinear relationships. The latter makes it possible to find hidden patterns in our data, which would have gone unnoticed otherwise. Additionally, GAM uses a regularization parameter to prevent overfitting the data!

I would like to refer again to the awesome blogpost about GAM modelling (GAM: The Predictive Modeling Silver Bullet) for the mathematical point of view. Furthermore it also explains how, for example, the best-fitting smooth functions are obtained using an algorithm. Additionally, it also explains how GAM prevents overfitting using a regularization parameter. In the remainder of this blog post, I would like to focus on the advantages and disadvantages of using GAM models to find the S-response curve for a fictional radio example.

## R versus Python

Let’s consider again the radio example of the <a href="" target="_blank">previous blogpost</a>. This time, however, we switch to R as programming language. That is because Python does not yet provide a good library for GAM modelling. <a href="http://statsmodels.sourceforge.net/" target="_blank">Statsmodels</a> does contain GAM modelling in its sandbox functionality, but GAM modelling in R is more advanced and widely supported. The two main packages in R that can be used to fit generalized additive models are gam and mgcv. We use <a href="http://people.bath.ac.uk/sw283/mgcv/" target="_blank">mgcv</a> because it uses a more general approach. The R code to create a fictional dataset with sales and radio GRPs can be found on <a href="https://github.com/thomhopmans" target="_blank">Github</a>.

Note that the number of sales on any given day depends on the day of the week (monday,..., sunday), the number of radio GRPs on that day and some normally distributed noise. Moreover, the effect of radio GRPs on sales is logistically distributed and thus follows an S-shape.

## Let the GAM(es) begin

We can now formulate the problem as a GAM problem by

<img alt="Equation (1)" />

where xmonday,…,xsaturday are day dummy variables and s1(x) is a smooth function. The *mcgv* package in R is used to solve the above GAM problem.

```R
  # Initialize GAM model with 1 smooth function for radio_grp
  b1 <- mgcv::gam(sales_total ~ s(radio_grp, bs='ps', sp=0.5)
                  + seasonality_monday + seasonality_tuesday 
                  + seasonality_wednesday + seasonality_thursday 
                  + seasonality_friday + seasonality_saturday, 
                  data=dat)
  
  # Output model results and store intercept for plotting later on
  summary_model      <- summary(b1)
  model_coefficients <- summary_model$p.table
  model_intercept    <- model_coefficients["(Intercept)", 1]
  
  
  # Plot the smooth predictor function to obtain the radio response curve
  p    <- predict(b1, type="lpmatrix")
  beta <- coef(b1)[grepl("radio_grp", names(coef(b1)))]
  s    <- p[,grepl("radio_grp", colnames(p))] %*% beta + model_intercept
```

The above code returns the following summary:

```
Family: gaussian 
Link function: identity 

Formula:
sales_total ~ s(radio_grp, bs = "ps", sp = 0.5) + seasonality_monday + 
    seasonality_tuesday + seasonality_wednesday + seasonality_thursday + 
    seasonality_friday + seasonality_saturday

Parametric coefficients:
                      Estimate Std. Error t value Pr(>|t|)    
(Intercept)             1.5687     0.1325   11.84   <2e-16 ***
seasonality_monday      3.8044     0.1840   20.68   <2e-16 ***
seasonality_tuesday     3.0623     0.1830   16.74   <2e-16 ***
seasonality_wednesday   4.0863     0.1839   22.22   <2e-16 ***
seasonality_thursday    5.0454     0.1829   27.58   <2e-16 ***
seasonality_friday      6.1710     0.1849   33.38   <2e-16 ***
seasonality_saturday    7.8875     0.1839   42.89   <2e-16 ***
---
Signif. codes:  0 ‘***’ 0.001 ‘**’ 0.01 ‘*’ 0.05 ‘.’ 0.1 ‘ ’ 1

Approximate significance of smooth terms:
               edf Ref.df    F p-value    
s(radio_grp) 3.848  4.571 1032  <2e-16 ***
---
Signif. codes:  0 ‘***’ 0.001 ‘**’ 0.01 ‘*’ 0.05 ‘.’ 0.1 ‘ ’ 1

R-sq.(adj) =   0.99   Deviance explained = 99.1%
GCV = 0.22855  Scale est. = 0.201     n = 90
```

This summary obviously looks different than when using OLS. However, it still returns statistics for the dummy coefficients such as the estimate, standard error and significance. The statistics for the dummy coefficients are interpreted in a similar manner as in OLS (so in this case Tuesday sales are three units higher compared to Sunday and all coefficients are statistically significant positive). The effect of radio GRPs is difficult to explain from this summary, but a visualization is very effective though! The code for this visualization can again be found on <a href="https://github.com/thomhopmans" target="_blank">Github</a>.

<img alt="S-curve visualization" />

Well, look at this… the GAM model almost perfectly captured the S-shaped effect of radio on sales! And that without all the hassle and extra steps we needed in the previous blog. GAM modelling is therefore a really awesome technique to estimate nonlinear relationships. But, before we jump to conclusions, lets first do some sense checks.

> “Far be it from me to ever let my common sense get in the way of my stupidity. I say we press on.”

The fictional dataset we created above is a somewhat ideal scenario: many radio observations and little noise/variance in the number of sales. So what happens if we use GAM modelling on datasets with less/more observations and less/more noise? The figure below shows the S-curve obtained using GAM for such different datasets.

<img alt="The S-curve for different amounts of noise and radio observations" />

It is not surprising that as the dataset contains more noise or less radio observations the estimated relationship of radio on sales fits worse. However, overall, it still provides a relatively accurate estimation. Even when the noise (standard deviation on the sales per day) is very high, the estimated curve still shows the S-curve effect of increasing returns at first and diminishing returns thereafter.

GAM modelling is therefore also useful when we have noisy data or few variable observations. We want to perform a second sense check however. That is, how does GAM perform when the observations are not well-balanced. For example when we have few observations with high GRP values. Note that this is often the case in practice because of obvious budget constraints. Therefore, we created a fictional dataset where the majority of the radio observations lies below 5 GRPs and only a few above. This was done by taking random radio GRP values from a N(4, 2)-distribution instead of the U[0,10] we used earlier. The figure below shows the estimated curve by the GAM model for this dataset with again variations in noise and observations.

<img alt="The S-curve for different amounts of noise and radio observations where the radio observations are clustered more at the beginning of the curve." />

We see that the GAM model now has more trouble to find the S-curved relationship of radio on sales. As the majority of the radio grp samples are clustered at the lower part of the curve, GAM has no troubles to estimate the increasing returns effect at the beginning of the curve. However, because of the few samples at the top of the curve, GAM has some troubles to estimate the decreasing returns effect after the <a href="http://mathworld.wolfram.com/InflectionPoint.html" target="_blank">inflection point</a>. Especially for the datasets with much noise GAM experiences difficulties and tries to linearly extrapolate the effect. After two sense checks though we can conclude that GAM modelling provides an excellent method to estimate S-curves for media mix modelling. Be careful though when the observations of the variable you want to model are really dense or clustered around a few points. As GAM modelling is not restricted to S-shaped relationships that could lead to strange curves. On the other hand, GAM modelling definitely provides more freedom in the relationships we can model. Additionally it prevents all the manual steps and hassle we needed in our previous blogpost. So, happy modelling and have a GAM time! :)