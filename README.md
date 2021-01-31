# bullets-server

Here is how to build it on your machine and deploy it to a fresh Ubuntu install, with a non-root user.


## On your machine

- clone the repository
- run `./build_docker.sh`
    - this will buld a docker image that runs the godot server after having exported the godot project to Linux/X11
- deploy to your server via ssh:
    - run `./deploy_ssh server-name`
        - replace server-name with the name of your server (or the alias in your ssh config)
        - this will copy the docker image and the runner script to your server

## On the server
### Setup
This is for a digitalocean docker droplet running ubuntu 20.04 LTS. Any ubuntu-like with docker will do.

It is assumed that this is a blank Ubuntu + Docker install, with no webserver running.

### User setup
- run `useradd bullets` to create a non-root user
- ssh into the server as that user

### Firewall
Ubuntu runs ufw. Configure ufw like this:

- copy `ufw_app_bullets_server` to `/etc/ufw/applications.d/bullets-server`
- copy `ufw_app_http_server` to `/etc/ufw/applications.d/http-server`
    - http is used for letsencrypt to get SSL certificates
- run `sudo ufw allow HTTP`
- run `sudo ufw allow bullets-server`

### letsencrypt
For SSL.

- `sudo snap install --classic certbot`
- `sudo certbot certonly --standalone`

#### Note: Check out [the certbot site](https://certbot.eff.org/lets-encrypt/ubuntufocal-other) to set up auto renewal. TODO: Write scripts that restart the container upon renewal!

### Load Docker image

- (You have scp-ed to the server)
- run `gunzip bullets-server.docker.tar.gz`
- run `docker load -i bullets-server.docker.tar`

### Run the server
- run `./run_container.sh your-host.your-domain.com` as user (bullets)
- you might get prompted for your password, to execute sudo commands

## In your bullets presentation
- press `M` for multiplayer
- change the url to `wss://your-host.your-domain.com:9000`
- click `Join!`
- repeat in other running presentation

