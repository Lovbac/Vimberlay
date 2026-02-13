class Logger {
    constructor(context) {
        this.context = context;
        this.enabled = true;
    }

    debug(message, ...args) {
        if (!this.enabled) return;
        console.debug(`${this.context}: ${message}`, ...args);
    }
}

export const log = new Logger("Vimberlay");
