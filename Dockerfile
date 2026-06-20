# --- Stage 1: Build Frontend ---
FROM node:18-alpine AS frontend-builder
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build

# --- Stage 2: Final Runtime ---
FROM node:18-alpine
WORKDIR /app

# 1. 复制后端服务器代码及依赖
COPY server/ ./server/
# 如果 server 目录下有独立的 package.json，则安装它，否则直接用根目录的
COPY package*.json ./
RUN npm install --production

# 2. 安装一个轻量级的静态文件服务器（用来跑前端 React 产物）
RUN npm install -g serve

# 3. 从第一阶段复制编译好的前端静态文件 (dist 目录)
COPY --from=frontend-builder /app/dist ./dist

# 4. 暴露端口：前端默认 5173(或用serve的3000)，后端 Socket.IO 默认 3001
EXPOSE 3000
EXPOSE 3001

# 5. 同时启动前端托管和后端 Node 服务
CMD ["sh", "-c", "serve -s dist -l 3000 & node server/index.js"]
