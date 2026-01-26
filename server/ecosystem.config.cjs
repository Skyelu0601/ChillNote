module.exports = {
  apps: [
    {
      name: "chillnote",
      cwd: "/root/chillnote-api/current",
      script: "dist/index.js",
      exec_mode: "fork",
      instances: 1,
      env: {
        NODE_ENV: "production"
      },
      env_file: "/root/chillnote-api/.env",
      kill_timeout: 5000,
      max_restarts: 10
    }
  ]
};

