const request = require('supertest');

// テスト環境では MongoDB に接続しないよう app.js 側で制御
process.env.NODE_ENV = 'test';
const { app } = require('../app');

describe('Health Check Endpoint', () => {
  it('should respond with 200 OK', async () => {
    const response = await request(app).get('/health');
    expect(response.status).toBe(200);
    expect(response.text).toBe('OK');
  });
});
