FROM node:20-alpine AS builder
WORKDIR /app
RUN npm install -g @angular/cli

WORKDIR /app/my-app
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build

FROM nginx:alpine

COPY --from=builder /app/my-app/dist/* /usr/share/nginx/html/ 

