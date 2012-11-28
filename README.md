NSURLConnection category for debugging HTTP(S) request/response.

Requires iOS 5.0 or higher.

Usage
-----

Before making any NSURLConnection calls, execute

    [NSURLConnection setupSwizzling];

will print out the most of NSURLConnection request/response stuff.