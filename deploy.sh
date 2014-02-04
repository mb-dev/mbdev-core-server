# global install: nodejs, gulp, forever, coffee-script, bower
# copy config
sudo stop site-api
git pull
npm install --production
sudo start site-api