FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm install -g @angular/cli && npm install
COPY . .
RUN npm run build

FROM nginx:alpine
COPY --from=builder /app/dist/my-app/browser /usr/share/nginx/html   
