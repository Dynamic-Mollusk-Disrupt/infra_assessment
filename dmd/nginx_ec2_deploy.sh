sudo yum install -y nginx
# Thanks https://www.netnea.com/cms/nginx-tutorial-2_minimal-nginx-configuration/ for the template file to start on my own
sudo tee /etc/nginx/nginx.conf <<'EOF'
daemon            on;
worker_processes  auto;
user              nginx;
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;

events {
    worker_connections  128;
}

http {
    server_tokens off;
    include       mime.types;
    charset       utf-8;

    access_log  /var/log/nginx/access.log;

    server {
        listen       80;
        listen       [::]:80;
        server_name  _;

        error_page    500 502 503 504  /50x.html;

        location      / {
            return 200 'hello groundfloor';
        }

    }

}
EOF
sudo systemctl enable nginx
sudo systemctl start nginx