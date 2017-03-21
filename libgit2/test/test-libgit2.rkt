#lang racket

(require "../main.rkt"
         rackunit
         rackunit/text-ui
         ffi/unsafe)

(define rm-rf
  (λ (file)
    (cond [(file-exists? file) (delete-file file)]
          [(directory-exists? file)
           (begin
             (map rm-rf
                  (map (λ (subfile) (build-path file subfile))
                       (directory-list file)))
             (delete-directory file))])))

(define temp-dir (find-system-path 'temp-dir))
(define clone-dir (build-path temp-dir "libgit2-clone"))
(define clear-clone-dir
  (λ () (unless (not (directory-exists? clone-dir))
          (rm-rf clone-dir))))

(define repo-dir (build-path temp-dir "test-libgit2"))
(define clear-repo-dir
  (λ () (unless (not (directory-exists? repo-dir))
          (rm-rf repo-dir))))

(run-tests
 (test-suite
  "libgit2"
  #:before (λ () (git_libgit2_init))
  #:after (λ () (git_libgit2_shutdown))
  
  (test-suite
   "clone"
   (clear-clone-dir)
   
   (test-case
    "git clone"
    (check-not-exn
     (λ ()
       (git_repository_free
        (git_clone "https://github.com/bbusching/libgit2.git"
                   (path->string (build-path temp-dir "libgit2-clone"))
                   #f)))))
   #;(test-case
      "git clone options"
      (check-not-exn
       (λ ()
         (let [(opts (malloc _git_clone_opts))]
           (git_clone_init_options opts 1)
           (free opts))))))

  (test-suite
   "repository"
   (clear-repo-dir)
   (make-directory repo-dir)
   
   (test-case
    "git repo init"
    (check-not-exn (λ () (git_repository_free
                          (git_repository_init (path->string repo-dir) #f)))))

   #;(test-case
      "git repo options"
      (clear-repo-dir)
      (make-directory repo-dir)
      (let [(init_opts (malloc _git_repository_init_opts))]
        (check-not-exn (λ () (git_repository_init_init_options init_opts 1)))
        (check-not-exn (λ () (git_repository_free
                              (git_repository_init_ext (path->string repo-dir) init_opts))))))
   
   (let [(repo (git_repository_open (path->string repo-dir)))]
     ;(check-true (git_repository_is_bare repo) "is bare") ;??? can't find git_repository_is_bare
     (test-case "git repo is_empty" (check-true (git_repository_is_empty repo) "is empty"))
     (test-case "git repo is_shallow" (check-false (git_repository_is_shallow repo) "is shallow"))
     (test-case "git repo namespace"
                (let [(ns "namespace")]
                  (check-not-exn (λ () (git_repository_set_namespace repo ns)))
                  (check-equal? (git_repository_get_namespace repo) ns)))
     (test-case "git repo workdir"
                (check-not-exn (λ () (git_repository_set_workdir repo (path->string repo-dir) #f)))
                (check-not-exn (λ () (git_repository_workdir repo))))
     (test-case "git repo odb"
                (let [(odb (git_repository_odb repo))]
                  ;(check-not-exn (λ () (git_repository_set_odb repo odb)))
                  (git_odb_free odb)))
     (test-case "git repo refdb"
                (let [(refdb (git_repository_refdb repo))]
                  ;(check-not-exn (λ () (git_repository_set_refdb repo refdb)))
                  (git_refdb_free refdb)))
     (test-case "git repo config"
                (let [(config (git_repository_config repo))]
                  ;(check-not-exn (λ () (git_repository_set_config repo config)))
                  (git_config_free config)))
     (test-case "git repo config_snapshot" (check-not-exn (λ () (git_config_free (git_repository_config_snapshot repo)))))
     (test-case "git repo state" (check-equal? (git_repository_state repo) 'GIT_REPOSITORY_STATE_NONE))
     (test-case "git repo path"
                (check-equal? (normal-case-path (string->path (git_repository_path repo)))
                              (normal-case-path (build-path repo-dir ".git\\"))))
     (test-case "git repo index"
                (let [(index (git_repository_index repo))]
                  ;(check-not-exn (λ () (git_repository_set_index repo index))) ;??? git_repository_set_index not found
                  (git_index_free index)))
     (test-case "git repo ident"
                (let [(name "Brad Busching")
                      (email "bradley.busching@gmail.com")]
                  (check-not-exn (λ () (git_repository_set_ident repo name email)))
                  (let-values ([(x y) (git_repository_ident repo)])
                    (begin (check-equal? name x)
                           (check-equal? email y)))))
     #;(test-case "git repo new"
                (check-not-exn (λ () (git_repository_free (git_repository_new)))))
     (git_repository_free repo))
   
   (test-case
    "git repo open bare"
    (clear-repo-dir)
    (make-directory repo-dir)
    (git_repository_free (git_repository_init (path->string repo-dir) #t))
    (check-not-exn (λ () (git_repository_free (git_repository_open_bare (path->string repo-dir))))))

   #;(let [(repo (git_repository_open (path->string clone-dir)))]
     (test-case "git repo head" (check-not-exn (λ () (git_reference_free (git_repository_head repo)))))
     (test-case "git repo detach head"
                (check-not-exn (λ () (git_repository_detach_head repo)))
                (check-true (git_repository_head_detached repo)))
     (test-case "git repo head unborn" (check-false (git_repository_head_unborn repo))))
   )
  (test-suite
   "signature"
   (clear-repo-dir)
   (make-directory repo-dir)
   (let [(repo (git_repository_init (path->string repo-dir) #f))]
     (test-case "default"
                (check-not-exn (λ () (git_signature_free (git_signature_default repo)))))
     (test-case "new"
                (check-not-exn (λ () (git_signature_free (git_signature_new "brad busching"
                                                                      "bradley.busching@gmail.com"
                                                                      0
                                                                      0)))))
     (test-case "now"
                (check-not-exn (λ () (git_signature_free (git_signature_now "brad busching"
                                                                      "bradley.busching@gmail.com")))))
     (let [(sig (git_signature_default repo))]
       (check-not-exn (λ () (git_signature_free (git_signature_dup sig))))
       (git_signature_free sig))))
  (test-suite
   "buf"
   (let [(buf (make-git_buf #f 0 0))]
     (check-not-exn (λ () (git_buf_grow buf 10)))
     (check-not-exn (λ () (git_buf_set buf (bytes 5 66 37 187 0 0 0) 7)))
     (check-true (git_buf_is_binary buf))
     (check-true (git_buf_contains_nul buf))
     (check-not-exn (λ () (git_buf_free buf)))))
  #;(test-suite
   "reference"
   (clear-repo-dir)
   (make-directory repo-dir)
   (let [(repo (git_repository_init (path->string repo-dir #f)))]
     ))
  )
 )