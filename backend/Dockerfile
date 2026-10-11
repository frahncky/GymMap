FROM dart:stable AS build

WORKDIR /app

COPY backend/pubspec.yaml backend/pubspec.lock ./backend/
RUN cd backend && dart pub get

COPY backend ./backend
RUN dart compile exe backend/server.dart -o /app/gymmap-backend

FROM dart:stable

WORKDIR /app
COPY --from=build /app/gymmap-backend /app/gymmap-backend

EXPOSE 8080

CMD ["/app/gymmap-backend"]
