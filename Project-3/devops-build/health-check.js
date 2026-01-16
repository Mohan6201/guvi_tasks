const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = process.env.PORT || 80;

// Health check endpoint
const healthCheck = (req, res) => {
  if (req.url === '/health') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ 
      status: 'healthy', 
      timestamp: new Date().toISOString(),
      uptime: process.uptime()
    }));
    return true;
  }
  return false;
};

// Metrics endpoint for Prometheus
const metrics = (req, res) => {
  if (req.url === '/metrics') {
    const uptime = process.uptime();
    const memoryUsage = process.memoryUsage();
    
    const metricsText = `
# HELP nodejs_uptime_seconds Process uptime in seconds
# TYPE nodejs_uptime_seconds counter
nodejs_uptime_seconds ${uptime}

# HELP nodejs_memory_usage_bytes Memory usage in bytes
# TYPE nodejs_memory_usage_bytes gauge
nodejs_memory_usage_bytes{type="rss"} ${memoryUsage.rss}
nodejs_memory_usage_bytes{type="heapTotal"} ${memoryUsage.heapTotal}
nodejs_memory_usage_bytes{type="heapUsed"} ${memoryUsage.heapUsed}
nodejs_memory_usage_bytes{type="external"} ${memoryUsage.external}

# HELP application_up Application health status
# TYPE application_up gauge
application_up 1
`;

    res.writeHead(200, { 'Content-Type': 'text/plain' });
    res.end(metricsText);
    return true;
  }
  return false;
};

// Simple static file server
const server = http.createServer((req, res) => {
  // Handle health check
  if (healthCheck(req, res)) return;
  
  // Handle metrics
  if (metrics(req, res)) return;
  
  // Serve static files
  let filePath = path.join(__dirname, 'build', req.url === '/' ? 'index.html' : req.url);
  
  const extname = path.extname(filePath);
  let contentType = 'text/html';
  
  switch (extname) {
    case '.js':
      contentType = 'text/javascript';
      break;
    case '.css':
      contentType = 'text/css';
      break;
    case '.json':
      contentType = 'application/json';
      break;
    case '.png':
      contentType = 'image/png';
      break;
    case '.jpg':
      contentType = 'image/jpg';
      break;
  }
  
  fs.readFile(filePath, (error, content) => {
    if (error) {
      if (error.code === 'ENOENT') {
        // Try serving index.html for SPA routing
        fs.readFile(path.join(__dirname, 'build', 'index.html'), (err, content) => {
          if (err) {
            res.writeHead(500);
            res.end('Server Error');
          } else {
            res.writeHead(200, { 'Content-Type': 'text/html' });
            res.end(content, 'utf-8');
          }
        });
      } else {
        res.writeHead(500);
        res.end('Server Error');
      }
    } else {
      res.writeHead(200, { 'Content-Type': contentType });
      res.end(content, 'utf-8');
    }
  });
});

server.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
  console.log(`Health check available at http://localhost:${PORT}/health`);
  console.log(`Metrics available at http://localhost:${PORT}/metrics`);
});
