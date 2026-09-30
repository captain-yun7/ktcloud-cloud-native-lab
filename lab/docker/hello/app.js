const express = require('express');

const app = express();
const port = process.env.PORT || 3000;

app.get('/', (req, res) => {
  res.send('hello, docker\n');
});

app.listen(port, () => {
  console.log(`hello app listening on port ${port}`);
});
