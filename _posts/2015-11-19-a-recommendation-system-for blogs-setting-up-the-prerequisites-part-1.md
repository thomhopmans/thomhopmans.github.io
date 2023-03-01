---
layout: post
title: "A recommendation system for blogs: Setting up the prerequisites (1)"
date: 2015-11-19 12:00:00 +0100
categories: data-science python recommendation-systems
image: /images/posts/2015/connection.jpg
author: Thom Hopmans
---

The goal of data science is typically described as creating value from Big Data. However, data science should also meet a second goal, that is, avoiding an information overload. One particular type of projects that really meet these two goals are recommendation engines. Online stores such as Amazon but also streaming services such as Netflix suffer from information overload. Customers can easily get lost in their large variety (millions) of products or movies. Recommendation engines help users narrow down the large variety by presenting possible options. Of course, these recommenders can randomly present options to users but this does not really decrease the information overload. Therefore these recommenders apply statistics and science to present ‘better’ solutions which are more likely to meet the expectations of the user. For example, a Netflix user who watched the movie Frozen gets similar children movies from Pixar as a recommendation to watch.

<img src="/images/posts/2016/netflix-recommendation.jpg" alt="Example of Netflix's recommendation system" />

In a series of three blog posts we will elaborate on how we can build a recommendation engine for our readers on The Marketing Technologist (TMT). TMT currently has over fifty blog posts covering varying topics from Data Science to coding in ReactJS. Browsing through all the blog posts is time consuming, especially as the number of posts is still increasing. Also chances are readers are only interested in a select few blog posts that lie in their area of interest. If a recommendation engine is able to select those articles an user is interested in then this can definitely be classified as creating value from data and preventing information overload.

## Two types of recommendation systems

Roughly speaking we can divide recommendation engines in two different types: **collaborative filtering** and **content-based**. As Wikipedia states “collaborative filtering is the process of filtering for information or patterns using techniques involving collaboration among multiple agents, viewpoints, data sources”. In our TMT case, this implies finding patterns among multiple readers. If several readers are interested in a particular set of articles it is very likely that a reader who starts reading one of these articles is also interested in the other articles from this set. Therefore, based upon the reading behavior of other users, suggestions are made to similar users.

Content-based recommendation engines are different as they base their recommendations on the properties of the product. In our case the products are TMT blog posts and the properties are the words within these posts. If a user is reading an article containing the words *'Google Analytics'* and *'Tag Manager'*, chances are that this user also likes reading other articles containing these words. Therefore, a content-based recommendation engine will recommend articles containing these words.

Note that since the recent change from Geek to The Marketing Technologist a very simple content-based filtering approach is integrated in TMT. That is, below each article five other related articles are shown to the user as suggestion for continued reading. The suggested articles are the five most recently published articles that contain any of the tags of the article the user is currently reading. In this simple example the tags of the articles can be seen as the properties of the product.

<img src="/images/posts/2016/recommender-systems.jpeg" alt="The principle behind collaborative and content-based filtering" />

Both systems have their pros and their cons. Content-based recommendation systems are limited in their possibilities as the recommended articles will be close to the article on which a set of recommendations is based. For example, a post about a specific feature in *'Google Analytics'* will give recommendations based upon similar words in other articles. However, an article about a specific feature in *'Snowplow'*, which is a similar analytics tool, is less likely to be recommended. Chances are though that users are interested in both posts as they both cover the theme analytics. Therefore, content-based recommendation systems are not good at finding hidden patterns.

Collaborative filtering outperforms content-based recommendation systems for discovering hidden patterns. Collaborative filtering looks at the reading behaviour of users and not specificly at the content of these articles. So if users reading blog posts about data science are also reading posts about conversion rate optimization (CRO), even when the content of the CRO articles is very different, collaborative filtering will recommend data science readers also CRO articles. The big con of collaborative filtering is that it needs a lot of historical user reading behaviour data in order to find these patterns. Content-based recommendation can be done with none to few historical data and are therefore easier to implement.

## Prerequisites for collaborative filtering

In the next two blog posts we are going to implement content-based and collorative filtering and analyse the results. However, in order to be able to do so we first need to set-up some prerequisites. For collaborative filtering this implies implementing a method with which we can measure the articles a user has read. Our colleague <a href="https://www.themarketingtechnologist.co/author/erik-driessen/" target="_blank">Erik Driessen</a> has implemented a method to track user reading behaviour in Google Analytics by using the client ID. Simo Ahava explains in his blog post <a href="http://www.simoahava.com/analytics/improve-data-collection-with-four-custom-dimensions/#2" target="_blank">Storing client ID in Google Analytics</a> how this can be done in an effective manner. Additionaly, because Erik has implemented <a href="https://www.themarketingtechnologist.co/track-content-performance-using-google-analytics-enhanced-ecommerce-report/" target="_blank">Enhanced Ecommerce for content</a>, we can track whether a user has fully read an article. Finally, in Google Analytics a custom report can be created which shows the client id and the posts the users has read.

Note that for now no cross-device solution is implemented yet. Therefore, if a user continues reading articles on a different device or removes his cookies, this behaviour cannot be connected to his earlier reading behaviour.

<img src="/images/posts/2016/ecommerce-for-content.png" alt="Example of a custom report in Google Analytics which shows reading behaviour on a user level" />

## Prerequisites for content-based

For content-based recommendations we are obviously going to need the content of all TMT articles. There are multiple methods to do so. One of these would be to extract the text of the articles directly from the database. However, as we are Geeks, it is more fun to create a Python script that automatically retrieves the articles and corresponding metrics such as author and category. Therefore we created a Python script that scrapes the articles from the TMT website in two steps. The code for step 1 and step 2 can be found on <a href="https://github.com/thomhopmans" target="_blank" />GitHub</a>.

### Step 1: Create a list of all TMT articles.

In Python the source of webpages can be loaded with the library `urllib2`. Using the command `urllib2.urlopen("http://www.themarketingtechnologist.co")` we can therefore load the source of the frontpage of our very own TMT blog. This frontpage always shows the ten most recent posts. Using the `BeautifulSoup` library we can then easily search through the DOM and extract all `article` elements with `class="post"` and store them in a Pandas dataframe. Additionally, within each of these elements we can search for author name and tags by searching for the corresponding elements in the DOM.

Because only the ten most recent blog posts are shown on the frontpage we also need to check whether there is an `Older posts >` button on the bottom of the page for more posts. Again, this can be done by searching for the proper DOM element, i.e. an a element with `class="older-posts"`. From the older posts link the URL to the next page can be extracted by using the `get` function to extract the value from the `href` attribute. We repeat the above process for each of the pages. In the end, we have a dataframe with the names, tags and author of all articles + a link to the article content.

### Step 2: Retrieving the content of each article.

In step 1 we stored a direct link to each article so we can download the full content of each article. There is only one particular problem, i.e. the content of each blog post is loaded via JavaScript. Therefore, if we use `urllib2` to load the static source of the article we don't get the content of the article. In order to execute JavaScript to load the content of the articles we actually need to render the posts by opening it in a web browser. Luckily this can be done using the popular `Selenium` library. Using a few lines of Python code in combination with Selenium a Firefox browser can be opened, directed to the proper URL and render the page. The DOM can then be searched for the information we want, e.g. the content of a blog post.

Note that because all JavaScript is executed using Selenium this also implies that Google Analytics is executed. Therefore, it is wise to take measures to prevent data pollution. For example, by adding your IP address to the list of filters in GA or by installing the <a href="https://chrome.google.com/webstore/detail/google-analytics-opt-out/fllaojicojecljbmefodhfapmkghcbnh" target="_blank">Google Analytics Opt-out Addon by Google</a>. Also note that we do not actually need to visually render each page in a Firefox webbrowser. You can also use a headless driver such as <a href="http://phantomjs.org/" target="_blank">PhantomJS</a> which renders the page in the background without the visual overhead.

That's it for now with respect to setting up the prerequisites. For the next months we collect reading behaviour on a user level for our collaborative filtering model. Therefore, in the next blog post we start by creating a content-based recommendation system and analyse its results.