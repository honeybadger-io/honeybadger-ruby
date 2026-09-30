require "tmpdir"
require "honeybadger/util/revision"

describe Honeybadger::Util::Revision do
  after do
    ENV.delete("HEROKU_SLUG_COMMIT")
  end

  it "detects capistrano revision" do
    root = FIXTURES_PATH.to_s
    expect(Honeybadger::Util::Revision.detect(root)).to eq("rspec testing")
  end

  it "detects git revision" do
    expect(Honeybadger::Util::Revision.detect).to eq(`git rev-parse HEAD`.strip)
  end

  it "detects heroku revision" do
    ENV["HEROKU_SLUG_COMMIT"] = "heroku revision"
    expect(Honeybadger::Util::Revision.detect).to eq("heroku revision")
  end

  it "returns nil when detected value is a blank string" do
    allow(Honeybadger::Util::Revision).to receive(:from_git).and_return(" ")
    expect(Honeybadger::Util::Revision.detect).to eq(nil)
  end

  it "returns nil when detected value is nil" do
    allow(Honeybadger::Util::Revision).to receive(:from_git).and_return(nil)
    expect(Honeybadger::Util::Revision.detect).to eq(nil)
  end

  describe "reading git files" do
    let(:sha) { "a" * 40 }
    let(:other_sha) { "b" * 40 }

    around do |example|
      Dir.mktmpdir do |dir|
        @root = dir
        example.run
      end
    end

    def write(path, content)
      file = File.join(@root, path)
      FileUtils.mkdir_p(File.dirname(file))
      File.write(file, content)
    end

    def detect
      Honeybadger::Util::Revision.detect(@root)
    end

    it "does not start a git process when the files resolve" do
      write(".git/HEAD", "ref: refs/heads/main\n")
      write(".git/refs/heads/main", "#{sha}\n")
      expect(IO).not_to receive(:popen)

      expect(detect).to eq(sha)
    end

    it "reads a detached HEAD" do
      write(".git/HEAD", "#{sha}\n")
      expect(detect).to eq(sha)
    end

    it "reads a sha256 detached HEAD" do
      sha256 = "c" * 64
      write(".git/HEAD", "#{sha256}\n")
      expect(detect).to eq(sha256)
    end

    it "reads a packed ref" do
      write(".git/HEAD", "ref: refs/heads/main\n")
      write(".git/packed-refs", <<~REFS)
        # pack-refs with: peeled fully-peeled sorted
        #{other_sha} refs/heads/other
        #{sha} refs/heads/main
        ^#{other_sha}
      REFS

      expect(detect).to eq(sha)
    end

    it "prefers a loose ref over a packed ref" do
      write(".git/HEAD", "ref: refs/heads/main\n")
      write(".git/refs/heads/main", "#{sha}\n")
      write(".git/packed-refs", "#{other_sha} refs/heads/main\n")

      expect(detect).to eq(sha)
    end

    it "follows a symbolic ref" do
      write(".git/HEAD", "ref: refs/heads/alias\n")
      write(".git/refs/heads/alias", "ref: refs/heads/main\n")
      write(".git/refs/heads/main", "#{sha}\n")

      expect(detect).to eq(sha)
    end

    it "reads a worktree through gitdir and commondir" do
      write("main/.git/refs/heads/feature", "#{sha}\n")
      write("main/.git/worktrees/feature/HEAD", "ref: refs/heads/feature\n")
      write("main/.git/worktrees/feature/commondir", "../..\n")
      write("feature/.git", "gitdir: ../main/.git/worktrees/feature\n")

      expect(Honeybadger::Util::Revision.detect(File.join(@root, "feature"))).to eq(sha)
    end

    it "falls back to the git command when the ref cannot be read" do
      write(".git/HEAD", "ref: refs/heads/.invalid\n")
      expect(IO).to receive(:popen).with(["git", "-C", @root, "rev-parse", "HEAD"], err: File::NULL).and_return("#{sha}\n")

      expect(detect).to eq(sha)
    end

    it "returns nil when the git command fails" do
      write(".git/HEAD", "ref: refs/heads/.invalid\n")
      allow(IO).to receive(:popen).and_raise(Errno::ENOENT)

      expect(detect).to eq(nil)
    end

    it "returns nil without starting git when there is no repository" do
      expect(IO).not_to receive(:popen)
      expect(detect).to eq(nil)
    end
  end
end
