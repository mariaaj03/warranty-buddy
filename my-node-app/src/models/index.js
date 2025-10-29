// This file exports data models used in the application, such as User and Post, along with methods for data manipulation.

class User {
    constructor(name, email) {
        this.name = name;
        this.email = email;
    }

    save() {
        // Logic to save user to the database
    }

    static findById(id) {
        // Logic to find a user by ID
    }
}

class Post {
    constructor(title, content) {
        this.title = title;
        this.content = content;
    }

    save() {
        // Logic to save post to the database
    }

    static findById(id) {
        // Logic to find a post by ID
    }
}

module.exports = {
    User,
    Post
};