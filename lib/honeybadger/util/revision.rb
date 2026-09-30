module Honeybadger
  module Util
    class Revision
      SHA_REGEX = /\A\h{40}(?:\h{24})?\z/
      MAX_SYMREF_DEPTH = 5

      class << self
        def detect(root = Dir.pwd)
          revision = from_heroku ||
            from_capistrano(root) ||
            from_git(root)

          revision = revision.to_s.strip
          return unless /\S/.match?(revision)

          revision
        end

        private

        # Requires (currently) alpha platform feature `heroku labs:enable
        # runtime-dyno-metadata`
        #
        # See https://devcenter.heroku.com/articles/dyno-metadata
        def from_heroku
          ENV["HEROKU_SLUG_COMMIT"]
        end

        def from_capistrano(root)
          file = File.join(root.to_s, "REVISION")
          return nil unless File.file?(file)
          begin
            File.read(file)
          rescue
            nil
          end
        end

        def from_git(root)
          git_dir = find_git_dir(root.to_s)
          return nil unless git_dir

          from_git_files(git_dir) || from_git_command(root.to_s)
        end

        # Resolves HEAD by reading the repository files, which avoids starting
        # a Git process. Returns nil for layouts it doesn't understand (e.g.
        # reftable), so the caller can fall back to the Git command.
        def from_git_files(git_dir)
          common_dir = find_common_dir(git_dir)
          ref = "HEAD"

          MAX_SYMREF_DEPTH.times do
            value = read_loose_ref(git_dir, common_dir, ref) || read_packed_ref(common_dir, ref)
            return nil unless value
            return value if SHA_REGEX.match?(value)

            ref = value.delete_prefix("ref:").strip
            return nil unless ref.start_with?("refs/")
          end

          nil
        rescue SystemCallError, IOError
          nil
        end

        def from_git_command(root)
          IO.popen(["git", "-C", root, "rev-parse", "HEAD"], err: File::NULL, &:read)
        rescue
          nil
        end

        # `.git` is a directory in a normal checkout, and a file containing
        # "gitdir: <path>" in worktrees and submodules.
        def find_git_dir(root)
          path = File.join(root, ".git")
          return path if File.directory?(path)
          return nil unless File.file?(path)

          gitdir = File.read(path)[/\Agitdir:\s*(.+)$/, 1]
          return nil unless gitdir

          dir = File.expand_path(gitdir.strip, root)
          dir if File.directory?(dir)
        rescue SystemCallError, IOError
          nil
        end

        # Worktrees keep HEAD in their own git dir, but share branch refs with
        # the main repository through the "commondir" file.
        def find_common_dir(git_dir)
          file = File.join(git_dir, "commondir")
          return git_dir unless File.file?(file)

          File.expand_path(File.read(file).strip, git_dir)
        end

        def read_loose_ref(git_dir, common_dir, ref)
          [git_dir, common_dir].uniq.each do |dir|
            file = File.join(dir, ref)
            return File.read(file).strip if File.file?(file)
          end

          nil
        end

        def read_packed_ref(common_dir, ref)
          file = File.join(common_dir, "packed-refs")
          return nil unless File.file?(file)

          File.foreach(file) do |line|
            sha, name = line.strip.split(" ", 2)
            return sha if name == ref
          end

          nil
        end
      end
    end
  end
end
