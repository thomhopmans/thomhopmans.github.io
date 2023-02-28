---
layout: post
title: The log10 of 0 is over 9000… right?
date: 2022-03-30 12:00:00 +0100
categories: datascience python practices numpy
tagline: Applying log10 with numpy on a subset of values, and why you should always add 'out' to numpy functions when using a where ufunc
image: /images/roberto-sorin-2XLqS8D0FKc-unsplash.png
image_caption: Photo by <a href="https://unsplash.com/@roberto_sorin?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText">Roberto Sorin</a> on <a href="https://unsplash.com/s/photos/mathematical-calculations?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText">Unsplash</a>
author: Thom Hopmans
---

Recently, one of our models was taking a very long time to fit after adding a new feature. This was unexpected, as on previous occasions the model fitting process was actually quite fast. The model in question was a linear SVM and we 
could see it was not converging anymore when fitting the model. The first thing to check for with linear SVMs when this happens is numerical or scaling issues in the training dataset, as libSVM is in theory guaranteed to 
converge (<a href="https://www.csie.ntu.edu.tw/~cjlin/libsvm/faq.html#f413" target="_blank">source</a>). Adding the new feature indeed resulted in numerical issues, i.e. a few values greater than 100.000 were remaining in the dataset after scaling. 
These values were dominating all other, much smaller, numerical values.

<figure>
  <img src="/images/svm-not-converging.gif" class="border shadow mb-3">
  <figcaption class="text-sm text-gray-600">Figure 1 – Example of a linear SVM not converging
</figcaption>
</figure>

## What went wrong? 

So why did the feature not scale properly? After all, our applied (and preferred) preprocessing method was to apply a clip negative (i.e. clip `x` to `[0, inf)`) followed by a log10 transformation to scale the model feature to a small interval. 
Needless to say, a tedious debugging process followed, where at some point even the term <a href="https://en.wikipedia.org/wiki/Heisenbug" target="_blank">Heisenbug</a> was used. Eventually, the culprit was found: the problem was the line where we apply numpy's log10 function.

The logarithm function is undefined for 0. So log10 was only applied on strictly positive values using `np.log10(arr, where=(arr > 0))`. Leaving all zero values untouched we expected this to be a well-defined transformation, 
i.e. no runtime warnings from applying log10 on zero. 

<figure>
  <img src="/images/log10undefined.png" class="border shadow mb-3">
  <figcaption class="text-sm text-gray-600">10log(0) = undefined</figcaption>
</figure>

Unfortunately, this implementation of  `where` in numpy statements can lead to unexpected behaviour, because we did not add an `out` argument. I hear you thinking… why do we need `out`? 
Well, the <a href="https://numpy.org/doc/stable/reference/generated/numpy.log10.html" target="_blank">numpy docs</a> state the following:

<blockquote class="text-md text-blue-600 text-left pl-5 mr-auto">
<b>where:</b> This condition is broadcast over the input. At locations where the condition is True, the out array will be set to the ufunc result. Elsewhere, the out array will retain its original value. Note that if an uninitialized out array is created via the default out=None, locations within it where the condition is False will remain uninitialized.
</blockquote>

Those uninitialized values can then be whatever value was in there previously! For example, a value from a completely different model feature on which the log10 was also applied. Makes sense, right? 
If you find this hard to believe, you can try it yourself using the following code snippet or on <a href="https://deepnote.com/project/Tech-Blog-JvG-Y0wGT2G2L6s8t8JAPg/%2Fnumpy_where_in_log10.ipynb" target="_blank">Deepnote</a>.
More about arrays without initializing entries, including examples, can be found in the numpy [empty()](https://numpy.org/doc/stable/reference/generated/numpy.empty.html) docs.

```python
import numpy as np
print(f"Numpy version: {np.__version__}")

abc = np.array([0.00000, 100, 1000])
print(f"Initialize numpy array: {abc}")

# Random transformation to make the next transformation go rogue
np.log10(abc)

# Unexpected result
print("Expected result after transformation: [0. 2. 3.]")
print("Actual result after transformation:", np.log10(abc, where=(abc>0.0)))

>>> Numpy version: 1.21.5 
>>> Initialize numpy array: [ 0. 100. 1000.]
>>> Expected result after transformation: [0. 2. 3.]
>>> Actual result after transformation: [-inf 2. 3.]
```

## How to deal with the problem? 

The solution in our case is simple though: we follow the docs. We initialize a new array full of zeros and set it in `out`. That way, all values that are untouched by our where clause, i.e. those greater than zero, are still initialized as zeros.
If we want to use `where > 10` our initialization would be a bit more complex, but still manageable. The code snippet below (or on <a href="https://deepnote.com/project/Tech-Blog-JvG-Y0wGT2G2L6s8t8JAPg/%2Fnumpy_where_in_log10.ipynb" target="_blank">Deepnote</a>) shows 
we now get the expected result, hurray! 🎉

```python
import numpy as np
print(f"Numpy version: {np.__version__}")

abc = np.array([0.00000, 100, 1000])
print(f"Initialize numpy array: {abc}")

# Random transformation to make the next transformation go rogue
np.log10(abc)

# Good result
print("Expected result after transformation: [0. 2. 3.]")
print(
    "Actual result after transformation:",
    np.log10(abc, out=np.zeros(abc.shape), where=(abc > 0.0)),
)

>>> Numpy version: 1.21.5
>>> Initialize numpy array: [   0.  100. 1000.]
>>> Expected result after transformation: [0. 2. 3.]
>>> Actual result after transformation: [0. 2. 3.]
```

Therefore, the proper way to use `where` (or other ufuncs) in numpy is by explicitly initializing an output array, i.e. 

<figure>
  <img src="/images/log10-carbon.png" class="border shadow mb-3">
</figure>

Now you also know!
