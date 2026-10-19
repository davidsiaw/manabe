# frozen_string_literal: true

class AddAccountsAndPasskeys < ActiveRecord::Migration[8.1]
  def change
    # A learner with an email is a registered account. citext so that the
    # unique index treats Foo@Example.com and foo@example.com as one address.
    add_column :learners, :email, :citext
    add_index :learners, :email, unique: true
    # The WebAuthn user handle. Opaque and stable, unlike the email.
    add_column :learners, :webauthn_id, :string
    add_index :learners, :webauthn_id, unique: true

    # A logged-in browser. Only a digest of the bearer token is stored.
    create_table :learner_sessions, id: :uuid do |t|
      t.references :learner, type: :uuid, null: false, foreign_key: true
      t.string :token_digest, null: false
      t.datetime :updated_at
    end
    add_index :learner_sessions, :token_digest, unique: true

    create_table :passkeys, id: :uuid do |t|
      t.references :learner, type: :uuid, null: false, foreign_key: true
      t.string :external_id, null: false
      t.text :public_key, null: false
      t.bigint :sign_count, null: false, default: 0
      t.datetime :updated_at
    end
    add_index :passkeys, :external_id, unique: true

    # Issued with registration or login options and used up by the matching
    # verification, at most once and before it expires.
    create_table :passkey_challenges, id: :uuid do |t|
      t.string :challenge, null: false
      t.string :purpose, null: false
      t.references :learner, type: :uuid, foreign_key: true, null: true # none for login
      t.citext :email
      t.datetime :expires_at, null: false
      t.datetime :updated_at
    end
    add_index :passkey_challenges, :challenge, unique: true
  end
end
