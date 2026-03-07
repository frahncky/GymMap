FROM dart:stable

WORKDIR /app

COPY pubspec.yaml pubspec.lock ./
RUN dart pub get

COPY backend ./backend
COPY lib ./lib

EXPOSE 8080

CMD ["dart", "run", "backend/server.dart"]
