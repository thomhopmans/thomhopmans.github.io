---
layout: post
title: Slashception with regexp_extract in Hiv
date: 2015-09-30 12:00:00 +0100
categories:
   - data engineering
   - python
   - hive
author: Thom Hopmans
---

As a Data Scientist I frequently need to work with regular expressions. Though the capabilities and power of regular expressions are enormous, I just cannot seem to like them a lot. That is because when they do not function as expected they can be a really time-consuming nightmare. In this blogpost I will describe the hours I lost last week because of something I now call slashception.

## JSONception

On most of our clients websites we have our own datalogger <a href="http://snowplowanalytics.com/" target="_blank">Snowplow</a> running next to the Google or Adobe Analytics implementation. Snowplow enables us to do much more in depth analysis on log level data than we are able to do with only Google or Adobe Analytics. For a particular project Snowplow was storing a JSON-object in its database. This JSON-object contained a key-value pair for which the value was another JSON-object. This nested JSON-object was however stored as a string value. To ensure that the whole JSON-object is syntactically correct, the string-formatted JSON-object contains several backslash-characters (\) to escape the quote-characters ("). An illustration of the JSON-object we are talking about is given below:

```json
{  
   "key1":"value1",
   "key2":{  
      "settings":{  
         "setting1":true,
         "setting2":"{\"client\":{\"id\":\"26480999\",\"name\":\"Thom\",\"age\":\"24\"}}"
      }
   }
}
```

## What's in a name?

For our analysis we were interested in the value in the key 'name'. In the example above that value would have been `Thom` (just a random name for illustration purposes... or maybe not thát random.). Our idea was to use the <a href="https://cwiki.apache.org/confluence/display/Hive/LanguageManual+UDF#LanguageManualUDF-StringFunctions" target="_blank">regexp_extract</a> function in Hive to extract the name key-value pair and store the value in a new column denoted by 'name'. In that way, we could use the name column in all our subsequent queries on the database. Confident and with high hopes we ran the following Hive query:

```sql
insert overwrite table data partition(run)
select 
original_json_object,
regexp_extract(original_json_object, 'name\\":\\"(.*?)\\', 1) as name,
run
from data;
```

Note that the regular expression we used was `regexp_extract(original_json_object, 'name\\":\\"(.*?)\\', 1)`. We used two slashes, because we have to escape the protected backslash character in regular expressions. The first backslash tells the regular expression we want to use the second backslash character literally. Unfortunately, this regular expression did not do the trick as it returned...

Confused by the result of `NULL` instead of `Thom` we called for help from the internet. Regex101.com is a site we regularly use to create and test our regular expressions. However, also Regex101 said that this regular expression was correct. That is, Regex101 stated that the test string `name\":\"Thom\"` is a match to the regular expression `name\\":\\"(.*?)\\"`. After spending already too much time looking for the solution on the internet and its community, it was time to call in the colleagues. Even they hadn't experienced this issue before and mentioned that two backslashes should be enough. I kind of suspect that the first colleague that reads this post immediately knows the solution to this problem but that he or she wasn't around at the time.

## We're taking the regex to Isengard

As a last resort we applied a trial and error approach. That is, we let our knowledge about escaping with slashes in regular expressions go and just tried what would happen if we widened our search, i.e. `regexp_extract(original_json_object, 'name(.*?),', 1)`. Funny enough, this returned `\":\"Thom\"`. Now we were getting somewhere. The regexp_extract function was function correctly, we only needed to narrow down the search.

The next try was `regexp_extract(original_json_object, 'name\(.*?),', 1)`. Note that we did not escape the backslash as this didn't work in our earlier attempts and we are now doing trial runs to locate the problem. The output of this regexp_extract function was `\":\"Thom\"`. So after adding the extra slash we still got the same output. It was almost like our added slash disappeared... We tried adding an additional slash then! Unfortunately, `regexp_extract(original_json_object, 'name\\(.*?),', 1)` returned an error:

```java
Caused by: java.util.regex.PatternSyntaxException: Unmatched closing ')' near index 16
name\(.*?),
                ^
	at java.util.regex.Pattern.error(Pattern.java:1924)
	at java.util.regex.Pattern.compile(Pattern.java:1669)
	at java.util.regex.Pattern.<init>(Pattern.java:1337)
	at java.util.regex.Pattern.compile(Pattern.java:1022)
	at org.apache.hadoop.hive.ql.udf.UDFRegExpExtract.evaluate(UDFRegExpExtract.java:51)
	... 23 more
```

If you look at the error message you see that the regular expression used by Hive was `name\(.*?),`. So the second slash disappeared and only one slash was used. As discussed before, our regular expression knowledge tells us that this regular expression will not work. That is because the backslash now escapes the opening bracket and thus states that this opening bracket has to be interpreted literally. Therefore, the closing bracket has no matching opening bracket anymore and the regular expression crashes.

## Slashception

So if two slashes translate to one slash in the regular expression, what happens when we use four? That should translate to the regular expression `name\\(.*?),`. Therefore we tried `regexp_extract(original_json_object, 'name\\\\(.*?),', 1)` which returned `":\"Thom\"`. Hurray, we found the solution to deal with the first slash: four slashes. Using the same logic we then used `regexp_extract(original_json_object, 'name\\\\:\\\\"(.*?)\\\\"', 1)` which returned `Thom`. Hurrah!

## Why tell me why

We were able to succesfully complete the task using the latter regexp_extract function. A few hours later I was still wondering though why we needed four slashes to escape one single slash. Because we now knew the solution to the problem it was much easier to find other people with the same problem via Google. This Stack Overflow post perfectly describes why we needed four slashes:

> You need to escape twice, once for Java, once for the regex. Java code is \\\\ makes a regex string of \\, i.e. two chars. But the regex needs an escape too, so it turns into \, i.e. one symbol ~Peter Lawrey

and additionally

> @Peter Lawrey's answer describes the mechanics. Basically, the "problem" is that backslash is an escape character in both Java string literals, and in the mini-language of regexes. So when you use a string literal to represent a regex, there are two sets of escaping to consider, depending on what you want the regex to mean. ~Stephen C

If you found this blogpost because you are experiencing a similar problem, I hope we saved you a lot of time!