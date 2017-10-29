FROM nginx

COPY nginx.conf /etc/nginx/nginx.conf

RUN apt-get update -y \
&& apt-get install -y curl \
&& curl -sSo /usr/local/share/ca-certificates/fakelerootx1.crt https://letsencrypt.org/certs/fakelerootx1.pem \
&& update-ca-certificates
