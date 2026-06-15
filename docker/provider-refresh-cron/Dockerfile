FROM alpine:3.20

RUN apk add --no-cache bash curl tzdata

WORKDIR /workspace

CMD ["crond", "-f", "-l", "8"]
