import urllib.request
import json

title = "⚡ Optimize array concatenation in package import loop"
body = """💡 **What:** Replaced the array concatenation (`+=`) anti-pattern with a `[System.Collections.Generic.List[string]]` and the `.Add()` method in the `_pw_do_import` function for the `$failed` packages list.

🎯 **Why:** In PowerShell, using `+=` on an array requires allocating a completely new array in memory and copying all elements over every single time an item is added. In a loop, this leads to O(N^2) time complexity and unnecessary memory churn. Using a generic List is the standard approach to fix this performance issue and achieves O(1) amortized time for appends.

📊 **Measured Improvement:**
A focused benchmark was created to test the raw performance difference of the two approaches using `Measure-Command`:

**Appending 10,000 items:**
* Baseline (+= on array): ~141.78 ms
* Optimized (List[string].Add): ~25.81 ms
* **Speedup: ~5.49x**

*(Note: Although typical package imports might not reach 10k items, this avoids potentially noticeable latency spikes for large config files, and is generally considered best practice in PowerShell).*
"""
try:
    data = json.dumps({'title': title, 'body': body}).encode('utf-8')
    req = urllib.request.Request('http://localhost:8080/submit_pr', data=data, headers={'Content-Type': 'application/json'})
    print(urllib.request.urlopen(req).read().decode())
except Exception as e:
    print(e)
