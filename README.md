NSURLConnection category for debugging HTTP(S) request/response.

It can be useful when using 3rd party binary library and wants to inspect what data is going on.


Usage
-----

Before making any NSURLConnection calls, execute

    [NSURLConnection setupSwizzling];

will print out the most of NSURLConnection request/response stuff.

----

Requires iOS 5.0 or higher.