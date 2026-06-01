# ---- stage 1: build ----
FROM oven/bun:1 AS builder
WORKDIR /app

# Copy lockfile first for layer caching
# Re-runs only if bun.lockb or package.json changes
COPY package.json bun.lockb* ./
RUN bun install --frozen-lockfile

# Copy source and build
COPY . .
RUN bun run build
# Output is now in /app/build/

# ---- stage 2: serve ----
FROM nginx:alpine AS runner

# Copy built static files
COPY --from=builder /app/build /usr/share/nginx/html

# Replace default nginx config with ours
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
