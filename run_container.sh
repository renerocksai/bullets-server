#!/usr/bin/sh

DOMAIN=$1

if [ -z "$1" ] ; then
    echo "Provide domain name"
    exit 0
fi

#sudo ufw allow bullets-server 
#sudo ufw allow HTTP   # for certbot
#sudo certbot renew
mkdir -p keys
sudo cp /etc/letsencrypt/live/$DOMAIN/fullchain.pem keys/
sudo cp /etc/letsencrypt/live/$DOMAIN/privkey.pem keys/
sudo chown -R $USER:$USER keys
docker run --rm -p 9000:9000 -v $(pwd)/keys:/keys bullets-server:latest 
