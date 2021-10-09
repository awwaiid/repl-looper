FROM node:16.9.1
LABEL maintainer "awwaiid@thelackthereof.org"

WORKDIR /app
COPY . /app
RUN npm install
RUN npm run build
CMD npm run serve
