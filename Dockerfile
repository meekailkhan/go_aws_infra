FROM public.ecr.aws/docker/library/golang:1.24.2-alpine

WORKDIR /app

COPY go.mod go.sum ./

RUN go mod download

COPY . .

RUN go build -o main .

EXPOSE 8080

CMd ["./main"]