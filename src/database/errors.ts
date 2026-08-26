export class DatabaseError extends Error {
  constructor(message: string, public readonly cause?: unknown) {
    super(message);
    this.name = 'DatabaseError';
  }
}

export class MigrationError extends DatabaseError {
  constructor(message: string, cause?: unknown) {
    super(message, cause);
    this.name = 'MigrationError';
  }
}

export class VectorStoreError extends DatabaseError {
  constructor(message: string, cause?: unknown) {
    super(message, cause);
    this.name = 'VectorStoreError';
  }
}

export class ValidationError extends DatabaseError {
  constructor(message: string, cause?: unknown) {
    super(message, cause);
    this.name = 'ValidationError';
  }
}

export class NotFoundError extends DatabaseError {
  constructor(message: string) {
    super(message);
    this.name = 'NotFoundError';
  }
}
