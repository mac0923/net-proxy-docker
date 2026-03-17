FROM alpine:latest

RUN apk add --no-cache bash curl tzdata

WORKDIR /workspace

CMD ["crond", "-f", "-l", "8"]
