FROM node:20-alpine AS builder
WORKDIR /app
RUN npm install -g @angular/cli

# Vérifie si le dossier my-app existe → si non, crée le projet
RUN if [ ! -d "my-app" ]; then \
    ng new my-app --routing --style=css --skip-git --directory .; \
fi

WORKDIR /app/my-app
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build

FROM nginx:alpine

COPY --from=builder /app/my-app/dist/* /usr/share/nginx/html/ 
