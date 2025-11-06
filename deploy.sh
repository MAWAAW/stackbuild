#!/bin/bash

echo "Build backend avec Docker..."
#MSYS_NO_PATHCONV=1 docker run --rm \
#  -v "/$(pwd)/backend:/app" \
#  -w /app \
#  maven:3.8.4-openjdk-17 \
#  mvn clean package -DskipTests

echo "Build frontend avec Docker..."
MSYS_NO_PATHCONV=1 docker run --rm \
  -v "/$(pwd)/frontend:/app" \
  -w /my-app \
  node:20-alpine \
  sh -c "npm install && npm run build"

echo "Lancer Docker Compose..."
docker compose up --build -d   