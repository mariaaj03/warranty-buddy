module.exports = {
    logger: (message) => {
        console.log(`[LOG] ${new Date().toISOString()}: ${message}`);
    },
    errorHandler: (err, req, res, next) => {
        console.error(err.stack);
        res.status(500).send('Something broke!');
    }
};