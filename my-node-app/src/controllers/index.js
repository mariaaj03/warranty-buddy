class IndexController {
    getIndex(req, res) {
        res.send('Welcome to the Index Page');
    }
}

module.exports = IndexController;