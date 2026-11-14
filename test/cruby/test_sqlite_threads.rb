require_relative "helper"

# Threads that each open their own handle query at the same time.
class TestSqliteThreads < TepTest
  TMP_DB = "/tmp/tep_test_threads_#{$$}.db"

  app_source <<~RB
    require 'sinatra'

    get '/threads' do
      setup = Tep::SQLite.new
      setup.open("#{TMP_DB}")
      setup.exec("PRAGMA journal_mode = WAL")
      setup.exec("CREATE TABLE IF NOT EXISTS hits (worker INTEGER, n INTEGER)")
      setup.exec("DELETE FROM hits")
      setup.close
      threads = []
      4.times do |w|
        threads << Thread.new(w) do |worker|
          db = Tep::SQLite.new
          db.open("#{TMP_DB}")
          db.exec("PRAGMA busy_timeout = 5000")
          ok = 0
          200.times do |i|
            db.prepare("INSERT INTO hits (worker, n) VALUES (?, ?)")
            db.bind_int(1, worker)
            db.bind_int(2, i)
            db.step
            db.finalize
            db.prepare("SELECT count(*), max(n) FROM hits WHERE worker = ?")
            db.bind_int(1, worker)
            ok += 1 if db.step == 1 && db.col_int(0) == i + 1 && db.col_int(1) == i
            db.finalize
          end
          db.close
          ok
        end
      end
      total = 0
      threads.each { |t| total += t.value }
      "ok=" + total.to_s
    end
  RB

  Minitest.after_run do
    ["", "-wal", "-shm"].each { |s| File.unlink(TMP_DB + s) if File.exist?(TMP_DB + s) }
  end

  def test_threads_with_own_handles
    assert_equal "ok=800", get("/threads").body.strip
  end
end
