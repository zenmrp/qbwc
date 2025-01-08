class CreateQbwcJobs < ActiveRecord::Migration[5.0]
  def change
    create_table :qbwc_jobs, force: true do |t|
      t.string :name
      t.string :company, limit: 1000
      t.string :worker_class, limit: 100
      t.boolean :enabled, null: false, default: false
      t.text :request_index, null: true, default: nil
      t.text :requests
      t.boolean :requests_provided_when_job_added, null: false, default: false
      t.text :data
      t.timestamps null: false

      t.index :name, unique: true
      t.index :company, length: 150
    end
  end
end
