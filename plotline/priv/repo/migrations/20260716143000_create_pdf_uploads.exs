defmodule Plotline.Repo.Migrations.CreatePdfUploads do
  use Ecto.Migration

  def change do
    create table(:pdf_uploads) do
      add(:user_id, references(:users, on_delete: :delete_all), null: false)
      add(:original_filename, :string, null: false)
      add(:stored_path, :string, null: false)
      add(:content_type, :string, null: false)
      add(:byte_size, :integer, null: false)
      add(:status, :string, null: false, default: "uploaded")
      add(:book_id, references(:books, on_delete: :nilify_all))

      timestamps(type: :utc_datetime)
    end

    create(index(:pdf_uploads, [:user_id]))
    create(unique_index(:pdf_uploads, [:stored_path]))
  end
end
