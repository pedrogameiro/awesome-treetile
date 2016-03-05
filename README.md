Treesome
========

Treesome is binary tree-based, dyamic tiling layout for Awesome 3.5 and latter.
Similarly to tmux, it can split current workeare either vertically or
horizontally, which can mimic the dyamic titling behavior of the i3wm.

This project is forked from (https://github.com/RobSis/treesome) and still under the development.


Use
---

1. Clone repository to your awesome directory

    `git clone http://github.com/RobSis/treesome.git ~/.config/awesome/treesome`

2. Add this line to your rc.lua below other require calls.

    `local treesome = require("treesome")`

3. And finally add the layout `treesome` to your layout table.

    ```lua
        local layouts = {
            ...
            treesome
        }
    ```

4. Options:
    *   if you set the in the rc.lua to let the new created client gain the focus, 
    for example: 
    ```lua
    
        ...
            { rule = { },
              properties = { focus = awful.client.focus.filter,

        ...
    ```

    then you should set the following option to make sure treesome works correctly 

        treesome.focusnew = true  

    Otherwise set 

        treesome.focusnew = false

    
    *   The following option controls the new client apprear on the left or the right side
    of current client: 
    
        
    ```lua
        treesome.direction = "right" -- or "left"
    ```


5. Restart and you're done.


### Optional steps

1. By default, direction of split is decided based on the dimensions of the last focused
   client. If you want you to force the direction of the split, bind keys to
   `treesome.vertical` and `treesome.horizontal` functions. For example:

    ```lua
    awful.key({ modkey }, "v", treesome.vertical),
    awful.key({ modkey }, "h", treesome.horizontal)
    ```


Screenshots
-----------

![screenshot](./screenshot.png)

TODO
----------
1. supporting the resizing of clients by mouse or keyboard.


Licence
-------

[GPL 2.0](http://www.gnu.org/licenses/gpl-2.0.html)
