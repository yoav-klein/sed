
In this example, we want to take each such line:
```
deb http://il.archive.ubuntu.com/ubuntu/ focal main restricted
```

And transform it to:
```
&& echo "http://il.archive.ubuntu.com/ubuntu/ focal main restricted" >> /etc/apt/source.list \
```

For this, we use the `^deb http://` as the address, and then two commands: `s` command to do the 
transformation, and the `p` to output it.

We run sed with `-n` because we don't want everything to be outputted

