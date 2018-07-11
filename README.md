# Init

```
helper ansible
source ~/usr/ext/ansible-stable-2.6/hacking/env-setup -q
helper git-config
test -f .saved-dates || git-store-dates
git-store-dates hooks
```
