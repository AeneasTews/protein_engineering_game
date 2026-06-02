FROM ghcr.io/cirruslabs/flutter:stable AS builder

ARG API_BASE_URL=http://localhost:8000

WORKDIR /app
COPY . .

RUN flutter pub get
RUN flutter build web --wasm --dart-define=API_BASE_URL=$API_BASE_URL


FROM nginx:alpine

COPY --from=builder /app/build/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
