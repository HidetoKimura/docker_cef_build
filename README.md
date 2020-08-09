# CEF build in Docker

# Preconditions

- Ubuntu 18.04 LTS

- Install docker and docker compose, and add non-root docker user. 
  - https://docs.docker.com/engine/install/ubuntu/
  - https://docs.docker.com/compose/install/
  - https://docs.docker.com/engine/install/linux-postinstall/

- execute the below command to use x11 in docker.

~~~
$ xhost +
~~~


## How to use

- If you'd like to change your work directory, please edit "setenv.sh"

- build container
~~~
$ . setenv.sh
$ docker-compose build
~~~

- start container
~~~
$ . setenv.sh
$ docker-compose up -d
~~~

- enter/re-enter container
~~~
$ docker-compose exec app /bin/bash
~~~

- stop container
~~~
$ docker-compose down
~~~

# run weston & wayland sample
- see flutter_wayland
  https://github.com/HidetoKimura/flutter_wayland
~~~
$ weston --width 800 --height 600 &
$ layer-add-surfaces 1000 10 &
$ 
~~~


