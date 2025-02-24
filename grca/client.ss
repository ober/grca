;; -*- Gerbil -*-
;; ©ober 2022
;; grca client library

(import
  :gerbil/gambit
  :ober/oberlib
  :std/crypto/cipher
  :std/error
  :std/format
  :std/generic/dispatch
  :std/iter
  :std/logger
  :std/misc/list
  :std/net/websocket
  :std/pregexp
  :std/srfi/13
  :std/sugar
  :std/text/base64
  :std/text/json
  :std/text/yaml)

(export #t)
(declare (not optimize-dead-definitions))

(def version "0.01")

(def program-name "grca")
(def config-file (format "~~/.~a.yaml" program-name)

(def user-list (hash))
(def channel-list (hash))

;; Client functions for your app here
(def (get-chat-list)
  (let-hash (load-config)
    (let (url (format "https://grca.com/api/conversations.list?token=~a&type=im" .token))
      (with ([status . body] (rest-call 'get url (default-headers)))
        (unless status
          (error body))
        (pi body)
        (let ((body2 (car body)))
          (when (table? body2)
            (pi body2)
            (let-hash body2
              .?channels)))))))

;; Config functions
(def (load-config)
  (let ((config (hash))
        (config-data (yaml-load config-file)))
    (unless (and (list? config-data)
                 (length>n? config-data 0)
                 (table? (car config-data)))
      (displayln (format "Could not parse your config ~a" config-file))
      (exit 2))

    (hash-for-each
     (lambda (k v)
       (hash-put! config (string->symbol k) v))
     (car config-data))

    (let-hash config
      (when (and .?key .?iv .?password)
        (hash-put! config 'token (get-password-from-config .key .iv .password)))
      (hash-put! config 'style (or .?style "org-mode"))
      (when .?secrets
        (let-hash (u8vector->object (base64-decode .secrets))
          (let ((password (get-password-from-config .key .iv .password)))
            (hash-put! config 'token password)
            config))))))


(def (default-headers)
  (let-hash (load-config)
    [
     ["Accept" :: "*/*"]
     ["Content-type" :: "application/json"]
     ]))

(def (config)
  (let-hash (load-config)
    (displayln (format "Please enter your ~a token: " program-name)
    (let* ((password (read-password ##console-port))
           (cipher (make-aes-256-ctr-cipher))
           (iv (random-bytes (cipher-iv-length cipher)))
           (key (random-bytes (cipher-key-length cipher)))
           (encrypted-password (encrypt cipher key iv password))
           (enc-pass-store (u8vector->base64-string encrypted-password))
           (iv-store (u8vector->base64-string iv))
           (key-store (u8vector->base64-string key))
           (secrets (base64-encode (object->u8vector
                                    (hash
                                     (password enc-pass-store)
                                     (iv iv-store)
                                     (key key-store))))))
      (displayln "Add the following secrets line to your " config-file)
      (displayln "")
      (displayln "secrets: " secrets))))

(def (get-password-from-config key iv password)
  (bytes->string
   (decrypt
    (make-aes-256-ctr-cipher)
    (base64-string->u8vector key)
    (base64-string->u8vector iv)
    (base64-string->u8vector password))))

