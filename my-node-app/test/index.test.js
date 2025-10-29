const request = require('supertest');
const app = require('../src/index'); // Adjust the path as necessary

describe('Index Controller', () => {
    it('should return a 200 status for the root route', async () => {
        const response = await request(app).get('/');
        expect(response.status).toBe(200);
    });

    // Add more tests for other routes and functionalities as needed
});