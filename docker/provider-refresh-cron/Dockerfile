FROM alpine:3.24.2

RUN apk add --no-cache bash curl tzdata

WORKDIR /workspace

CMD ["crond", "-f", "-l", "8"]
