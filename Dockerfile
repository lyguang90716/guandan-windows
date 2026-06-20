# --- Stage 1: 编译前端 React ---
FROM node:18-alpine AS frontend-builder
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build

# --- Stage 2: 运行后端并用 Nginx 合并端口 ---
FROM node:18-alpine
WORKDIR /app

# 1. 安装 Nginx 和 pm2（用来同时守护 Node 和 Nginx 进程）
RUN apk add --no-cache nginx && npm install -g pm2

# 2. 复制并安装后端依赖
COPY server/ ./server/
COPY package*.json ./
RUN npm install --production

# 3. 复制前端编译产物到 Nginx 目录
COPY --from=frontend-builder /app/dist /usr/share/nginx/html

# 4. 直接在容器内写入 Nginx 配置文件，实现单端口分流
RUN echo ' \
server { \
    listen 80; \
    \
    # 1. 访问根目录时，直接返回 React 网页 \
    location / { \
        root /usr/share/nginx/html; \
        index index.html; \
        try_files $uri $uri/ /index.html; \
    } \
    \
    # 2. 当网页连接 socket.io 时，Nginx 悄悄转发给后端的 3001 端口 \
    location /socket.io/ { \
        proxy_pass http://127.0.0.1:3001; \
        proxy_http_version 1.1; \
        proxy_set_header Upgrade $http_upgrade; \
        proxy_set_header Connection "Upgrade"; \
        proxy_set_header Host $host; \
    } \
}' > /etc/nginx/http.d/default.conf

# 5. 此时对外只需要暴露一个 80 端口
EXPOSE 80

# 6. 启动后端服务和 Nginx
CMD ["sh", "-c", "node server/index.js & nginx -g 'daemon off;'"]
