# Use your base Node image
FROM node:22-alpine

# Set the working directory
WORKDIR /app

# Copy package.json and package-lock.json first (for caching)
COPY package*.json ./

# Install dependencies
RUN npm install

# COPY THE REST OF YOUR APPLICATION CODE (This is the missing step)
# This copies everything from your local directory into /app in the container
COPY . . 

# Start the application
CMD ["npm", "start"]