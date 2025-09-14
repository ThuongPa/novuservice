# Hướng dẫn Deploy Novu Service lên Server

## Tổng quan

Hướng dẫn này sẽ giúp bạn thiết lập GitHub Actions để deploy ứng dụng Novu Service lên server `103.200.24.110` với domain `novuservice.quantriso.vn`.

## Các bước chuẩn bị

### 1. Thiết lập Server

#### Kết nối SSH vào server:

```bash
ssh dev@103.200.24.110
# Password: zqpmmpqz
```

#### Cài đặt Docker và Docker Compose:

```bash
# Cập nhật hệ thống
sudo apt update && sudo apt upgrade -y

# Cài đặt Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker dev

# Cài đặt Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Khởi động lại session
exit
ssh dev@103.200.24.110
```

#### Cài đặt Nginx:

```bash
sudo apt install nginx -y
sudo systemctl enable nginx
sudo systemctl start nginx
```

#### Cài đặt Certbot (cho SSL):

```bash
sudo apt install certbot python3-certbot-nginx -y
```

### 2. Tạo thư mục dự án trên server:

```bash
mkdir -p /home/dev/novuservice
cd /home/dev/novuservice
```

### 3. Thiết lập Nginx:

#### Copy file cấu hình nginx:

```bash
sudo cp nginx/novuservice.conf /etc/nginx/sites-available/novuservice.quantriso.vn
sudo ln -s /etc/nginx/sites-available/novuservice.quantriso.vn /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

#### Tạo SSL certificate:

```bash
sudo certbot --nginx -d novuservice.quantriso.vn
```

### 4. Thiết lập GitHub Secrets

Vào GitHub repository → Settings → Secrets and variables → Actions, thêm các secrets sau:

#### SSH Configuration:

- `SSH_PRIVATE_KEY`: Private key để kết nối SSH (tạo bằng `ssh-keygen`)

#### Database Configuration:

- `MONGO_INITDB_ROOT_USERNAME`: admin
- `MONGO_INITDB_ROOT_PASSWORD`: [mật khẩu MongoDB mạnh]
- `MONGO_INITDB_DATABASE`: novu
- `MONGO_URL`: mongodb://admin:[password]@mongodb:27017/novu?authSource=admin

#### Security Keys:

- `JWT_SECRET`: [chuỗi bí mật JWT mạnh, ít nhất 32 ký tự]
- `NOVU_SECRET_KEY`: [chuỗi bí mật Novu mạnh, ít nhất 32 ký tự]
- `STORE_ENCRYPTION_KEY`: [chuỗi mã hóa mạnh, ít nhất 32 ký tự]

#### Storage Configuration:

- `STORAGE_SERVICE`: local
- `S3_BUCKET_NAME`: [nếu sử dụng S3]
- `S3_REGION`: [nếu sử dụng S3]
- `AWS_ACCESS_KEY_ID`: [nếu sử dụng S3]
- `AWS_SECRET_ACCESS_KEY`: [nếu sử dụng S3]

#### Optional Services:

- `SENTRY_DSN`: [nếu sử dụng Sentry]
- `SENDGRID_API_KEY`: [nếu sử dụng SendGrid]

### 5. Tạo SSH Key Pair

#### Trên máy local:

```bash
ssh-keygen -t rsa -b 4096 -C "github-actions@novuservice"
# Lưu private key vào GitHub Secrets
# Copy public key vào server
```

#### Trên server:

```bash
# Thêm public key vào authorized_keys
echo "ssh-rsa [public_key_content]" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

### 6. Thiết lập Git trên server:

```bash
cd /home/dev/novuservice
git init
git remote add origin https://github.com/[username]/[repository].git
git pull origin main
```

## Quy trình Deploy

### Tự động (qua GitHub Actions):

1. Push code lên branch `main`
2. GitHub Actions sẽ tự động:
   - Tạo file `.env` từ secrets
   - Copy code lên server
   - Chạy `docker-compose pull`
   - Restart các services
   - Kiểm tra health

### Thủ công (trên server):

```bash
cd /home/dev/novuservice
./deploy.sh
```

## Kiểm tra Deploy

### Kiểm tra services:

```bash
docker-compose ps
```

### Kiểm tra logs:

```bash
docker-compose logs -f [service_name]
```

### Kiểm tra health:

```bash
curl https://novuservice.quantriso.vn/health
curl https://novuservice.quantriso.vn/v1/health-check
```

## Troubleshooting

### Nếu container API báo "unhealthy":

Vấn đề này thường xảy ra do health check sử dụng `curl` nhưng container không có `curl`. Đã được sửa trong docker-compose.prod.yml:

```bash
# Kiểm tra health check
docker exec novu-api-prod wget -q --spider http://localhost:3000/v1/health-check

# Nếu vẫn lỗi, restart container
docker-compose restart novu-api
```

### Nếu services không start:

```bash
# Xem logs
docker-compose logs

# Restart services
docker-compose restart

# Rebuild containers
docker-compose up -d --force-recreate
```

### Nếu nginx không hoạt động:

```bash
# Kiểm tra config
sudo nginx -t

# Xem logs
sudo tail -f /var/log/nginx/error.log

# Restart nginx
sudo systemctl restart nginx
```

### Nếu SSL không hoạt động:

```bash
# Renew certificate
sudo certbot renew

# Test renewal
sudo certbot renew --dry-run
```

## Monitoring

### Xem resource usage:

```bash
docker stats
```

### Xem disk usage:

```bash
docker system df
```

### Backup database:

```bash
docker-compose exec mongodb mongodump --out /data/backup
```

## Cập nhật

### Cập nhật code:

```bash
git pull origin main
docker-compose pull
docker-compose up -d
```

### Cập nhật nginx config:

```bash
sudo nginx -t
sudo systemctl reload nginx
```

## Bảo mật

### Firewall:

```bash
sudo ufw allow 22
sudo ufw allow 80
sudo ufw allow 443
sudo ufw enable
```

### Regular updates:

```bash
sudo apt update && sudo apt upgrade -y
docker-compose pull
docker-compose up -d
```

## Liên hệ

Nếu gặp vấn đề, hãy kiểm tra:

1. Logs của services: `docker-compose logs`
2. Logs của nginx: `sudo tail -f /var/log/nginx/error.log`
3. Status của services: `docker-compose ps`
4. Health checks: `curl https://novuservice.quantriso.vn/health`
