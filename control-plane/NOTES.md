<!-- handle_errors 502 503 504 {
    rewrite * /waking/Workstation?next={http.request.orig_uri}
    reverse_proxy http://100.118.49.86:8000
} -->