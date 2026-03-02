(in-package :glib-test)

(def-suite gio-file-info :in gio-suite)
(in-suite gio-file-info)

;;; --- Types and Values -------------------------------------------------------

;;;     GFileInfo

(test g-file-info-class
  ;; Check type
  (is (g:type-is-object "GFileInfo"))
  ;; Check registered symbol
  (is (eq 'gio:file-info
          (glib:symbol-for-gtype "GFileInfo")))
  ;; Check type initializer
  (is (eq (g:gtype "GFileInfo")
          (g:gtype (cffi:foreign-funcall "g_file_info_get_type" :size))))
  ;; Check parent
  (is (eq (g:gtype "GObject")
          (g:type-parent "GFileInfo")))
  ;; Check children
  (is (equal '()
             (glib-test:list-children "GFileInfo")))
  ;; Check interfaces
  (is (equal '()
             (glib-test:list-interfaces "GFileInfo")))
  ;; Check class properties
  (is (equal '()
             (glib-test:list-properties "GFileInfo")))
  ;; Check signals
  (is (equal '()
             (glib-test:list-signals "GFileInfo")))
  ;; Check class definition
  (is (equal '(GOBJECT:DEFINE-GOBJECT "GFileInfo" GIO:FILE-INFO
                      (:SUPERCLASS GOBJECT:OBJECT :EXPORT T :INTERFACES NIL
                       :TYPE-INITIALIZER "g_file_info_get_type")
                      NIL)
             (gobject:get-gtype-definition "GFileInfo"))))

;;; --- Functions --------------------------------------------------------------

;;;     g_file_info_new

(test g-file-info-new
  (glib-test:with-check-memory (info)
    (is (typep (setf info (g:file-info-new)) 'g:file-info))))

;;;     g_file_info_clear_status
;;;     g_file_info_copy_into
;;;     g_file_info_dup

;;;     g:file-info-attribute

(test g-file-info-attribute.1
  (glib-test:with-check-memory (info file :strong 2)
    (let ((path (glib-sys:sys-path "test/rtest-gio-file.lisp")))
      (is (typep (setf file (g:file-new-for-path path)) 'g:object))
      (is (typep (setf info
                       (g:file-query-info file "standard::*" :none))
                 'g:file-info))
      (is (= 1 (g:file-info-attribute info "standard::type")))
      (is-false (g:file-info-attribute info "standard::is-hidden"))
      (is-false (g:file-info-attribute info "standard::is-backup"))
      (is-false (g:file-info-attribute info "standard::is-symlink"))
      (is (string= "rtest-gio-file.lisp"
                   (g:file-info-attribute info "standard::name")))
      (is (string= "rtest-gio-file.lisp"
                   (g:file-info-attribute info "standard::display-name")))
      (is (string= "rtest-gio-file.lisp"
                   (g:file-info-attribute info "standard::edit-name")))
      (is (string= "rtest-gio-file.lisp"
                   (g:file-info-attribute info "standard::copy-name")))
      (is (typep (g:file-info-attribute info "standard::icon") 'g:themed-icon))
      (is (string= "text/x-common-lisp"
                   (g:file-info-attribute info "standard::content-type")))
      (is (string= "text/x-common-lisp"
                   (g:file-info-attribute info "standard::fast-content-type")))
      (is (= 8420 (g:file-info-attribute info "standard::size")))
      (is (= 12288 (g:file-info-attribute info "standard::allocated-size")))
      (is (typep (g:file-info-attribute info "standard::symbolic-icon")
                 'g:themed-icon)))))

(test g-file-info-attribute.2
  (glib-test:with-check-memory (info file :strong 2)
    (let ((path (glib-sys:sys-path "test/rtest-gio-file.lisp")))
      (is (typep (setf file (g:file-new-for-path path)) 'g:object))
      (is (typep (setf info
                       (g:file-query-info file "standard::*" :none))
                 'g:file-info))
      (is (= 1 (g:file-info-attribute info "standard::type")))
      (is-true (setf (g:file-info-attribute info "standard::is-hidden") t))
      (is-true (g:file-info-attribute info "standard::is-hidden"))
      (is-true (setf (g:file-info-attribute info "standard::is-backup") t))
      (is-true (g:file-info-attribute info "standard::is-backup"))
      (is-true (setf (g:file-info-attribute info "standard::is-symlink") t))
      (is-true (g:file-info-attribute info "standard::is-symlink"))
      (is (string= "test"
                   (setf (g:file-info-attribute info "standard::name") "test")))
      (is (string= "test" (g:file-info-attribute info "standard::name")))
      (is (string= "test"
                   (setf (g:file-info-attribute info "standard::display-name")                         "test")))
      (is (string= "test"
                   (g:file-info-attribute info "standard::display-name")))
      (is (string= "test"
                   (setf (g:file-info-attribute info "standard::edit-name")
                         "test")))
      (is (string= "test" (g:file-info-attribute info "standard::edit-name")))
      (is (string= "test"
                   (setf (g:file-info-attribute info "standard::copy-name")
                         "test")))
      (is (string= "test"
                   (g:file-info-attribute info "standard::copy-name")))
      (is (typep (setf (g:file-info-attribute info "standard::icon")
                       (g:themed-icon-new "gtk-ok")) 'g:themed-icon))
      (is (typep (g:file-info-attribute info "standard::icon") 'g:themed-icon))
      (is (string= "text/plain"
                   (setf (g:file-info-attribute info "standard::content-type")
                         "text/plain")))
      (is (string= "text/plain"
                   (g:file-info-attribute info "standard::content-type")))
      (is (string= "text/plain"
                   (setf (g:file-info-attribute info "standard::fast-content-type")
                         "text/plain")))
      (is (string= "text/plain"
                   (g:file-info-attribute info "standard::fast-content-type")))
      (is (= 12000 (setf (g:file-info-attribute info "standard::size") 12000)))
      (is (= 12000 (g:file-info-attribute info "standard::size")))
      (is (= 24000 (setf (g:file-info-attribute info "standard::allocated-size")
                         24000)))
      (is (= 24000 (g:file-info-attribute info "standard::allocated-size")))
      (is (typep (setf (g:file-info-attribute info "standard::symbolic-icon")
                       (g:themed-icon-new "gtk-ok")) 'g:themed-icon))
      (is (typep (g:file-info-attribute info "standard::symbolic-icon")
                 'g:themed-icon)))))

;;;     g_file_info_get_attribute_string                    not exported
;;;     g_file_info_set_attribute_string
;;;     g_file_info_get_attribute_byte_string
;;;     g_file_info_set_attribute_byte_string
;;;     g_file_info_get_attribute_boolean
;;;     g_file_info_set_attribute_boolean
;;;     g_file_info_get_attribute_uint32
;;;     g_file_info_set_attribute_uint32
;;;     g_file_info_get_attribute_int32
;;;     g_file_info_set_attribute_int32
;;;     g_file_info_get_attribute_uint64
;;;     g_file_info_set_attribute_uint64
;;;     g_file_info_get_attribute_int64
;;;     g_file_info_set_attribute_int64
;;;     g_file_info_get_attribute_object
;;;     g_file_info_set_attribute_object
;;;     g_file_info_get_attribute_stringv
;;;     g_file_info_set_attribute_stringv

;;;     g_file_info_get_access_date_time                    Since 2.70
;;;     g_file_info_set_access_date_time                    Since 2.70

(test g-file-info-access-date-time.1
  (glib-test:with-check-memory (info)
    (is (typep (setf info (g:file-info-new)) 'g:file-info))
    (is (= 0 (setf (g:file-info-access-date-time info) 0)))
    (is (= 0 (g:file-info-access-date-time info)))))

(test g-file-info-access-date-time.2
  (glib-test:with-check-memory (info)
    (let ((utime (get-universal-time)))
      (is (typep (setf info (g:file-info-new)) 'g:file-info))
      (is (= utime (setf (g:file-info-access-date-time info) utime)))
      (is (= utime (g:file-info-access-date-time info))))))

;;;     g_file_info_get_attribute_as_string

(test g-file-info-attribute-as-string
  (glib-test:with-check-memory (info file)
    (let ((path (glib-sys:sys-path "test/rtest-gio-file.lisp")))
      (is (typep (setf file (g:file-new-for-path path)) 'g:object))
      (is (typep (setf info
                       (g:file-query-info file "standard::*" :none))
                 'g:file-info))

      (is (string= "rtest-gio-file.lisp"
                   (g:file-info-attribute-as-string info "standard::name")))

      (is (string= "1"
                   (g:file-info-attribute-as-string info "standard::type")))
      (is (string= "FALSE"
                   (g:file-info-attribute-as-string info "standard::is-hidden")))
      (is (string= "FALSE"
                   (g:file-info-attribute-as-string info "standard::is-backup")))
      (is (string= "FALSE"
                   (g:file-info-attribute-as-string info "standard::is-symlink")))
      (is (string= "rtest-gio-file.lisp"
                   (g:file-info-attribute-as-string info "standard::name")))
      (is (string= "rtest-gio-file.lisp"
                   (g:file-info-attribute-as-string info "standard::display-name")))
      (is (string= "rtest-gio-file.lisp"
                   (g:file-info-attribute-as-string info "standard::edit-name")))
      (is (string= "rtest-gio-file.lisp"
                   (g:file-info-attribute-as-string info "standard::copy-name")))
      #+nil
      (is (string= "GThemedIcon:0x5a8b0b2faa30"
                   (g:file-info-attribute-as-string info "standard::icon")))
      (is (string= "text/x-common-lisp"
                   (g:file-info-attribute-as-string info "standard::content-type")))
      (is (string= "text/x-common-lisp"
                   (g:file-info-attribute-as-string info "standard::fast-content-type")))
      (is (string= "8420"
                   (g:file-info-attribute-as-string info "standard::size")))
      (is (string= "12288"
                   (g:file-info-attribute-as-string info "standard::allocated-size")))
      #+nil
      (is (string= "GThemedIcon:0x5a8b0b2fab90"
                   (g:file-info-attribute-as-string info "standard::symbolic-icon")))
)))

;;;     g_file_info_get_attribute_data

;;;     g_file_info_get_attribute_file_path                 Since 2.78
;;;     g_file_info_set_attribute_file_path                 Since 2.78

;;;     g_file_info_get_attribute_status
;;;     g_file_info_set_attribute_status

#+nil
(test g-file-info-attribute-status
  (glib-test:with-check-memory (info file)
    (let ((path (glib-sys:sys-path "test/rtest-gio-file.lisp")))
      (is (typep (setf file (g:file-new-for-path path)) 'g:object))
      (is (typep (setf info
                       (g:file-query-info file "standard::*" :none))
                 'g:file-info))

      (is-false (g:file-info-attribute-status info "standard::type"))
      (is-false (g:file-info-attribute-status info "standard::is-hidden"))
      (is-false (g:file-info-attribute-status info "standard::is-backup"))
      (is-false (g:file-info-attribute-status info "standard::is-symlink"))
      (is-false (g:file-info-attribute-status info "standard::name"))
      (is-false (g:file-info-attribute-status info "standard::display-name"))
      (is-false (g:file-info-attribute-status info "standard::edit-name"))
      (is-false (g:file-info-attribute-status info "standard::copy-name"))
      (is-false (g:file-info-attribute-status info "standard::icon"))
      (is-false (g:file-info-attribute-status info "standard::content-type"))
      (is-false (g:file-info-attribute-status info "standard::fast-content-type"))
      (is-false (g:file-info-attribute-status info "standard::size"))
      (is-false (g:file-info-attribute-status info "standard::allocated-size"))
      (is-false (g:file-info-attribute-status info "standard::symbolic-icon"))
)))

;;;     g_file_info_get_attribute_type

(test g-file-info-attribute-type
  (glib-test:with-check-memory (info file)
    (let ((path (glib-sys:sys-path "test/rtest-gio-file.lisp")))
      (is (typep (setf file (g:file-new-for-path path)) 'g:object))
      (is (typep (setf info
                       (g:file-query-info file "standard::*" :none))
                 'g:file-info))
      (is (eq :uint32 (g:file-info-attribute-type info "standard::type")))
      (is (eq :boolean (g:file-info-attribute-type info "standard::is-hidden")))
      (is (eq :boolean (g:file-info-attribute-type info "standard::is-backup")))
      (is (eq :boolean (g:file-info-attribute-type info "standard::is-symlink")))
      (is (eq :byte-string (g:file-info-attribute-type info "standard::name")))
      (is (eq :string (g:file-info-attribute-type info "standard::display-name")))
      (is (eq :string (g:file-info-attribute-type info "standard::edit-name")))
      (is (eq :string (g:file-info-attribute-type info "standard::copy-name")))
      (is (eq :object (g:file-info-attribute-type info "standard::icon")))
      (is (eq :string (g:file-info-attribute-type info "standard::content-type")))
      (is (eq :string (g:file-info-attribute-type info "standard::fast-content-type")))
      (is (eq :uint64 (g:file-info-attribute-type info "standard::size")))
      (is (eq :uint64 (g:file-info-attribute-type info "standard::allocated-size")))
      (is (eq :object (g:file-info-attribute-type info "standard::symbolic-icon"))))))

;;;     g_file_info_set_attribute_mask

;;;     g_file_info_get_content_type
;;;     g_file_info_get_creation_date_time                  Since 2.70
;;;     g_file_info_get_deletion_date
;;;     g_file_info_get_display_name
;;;     g_file_info_get_edit_name
;;;     g_file_info_get_etag
;;;     g_file_info_get_file_type
;;;     g_file_info_get_icon
;;;     g_file_info_get_is_backup
;;;     g_file_info_get_is_hidden
;;;     g_file_info_get_is_symlink

;;;     g_file_info_get_modification_time                   Deprecated 2.62

;;;     g_file_info_get_modification_date_time
;;;     g_file_info_get_name
;;;     g_file_info_get_size

(test g-file-info-name
  (glib-test:with-check-memory (info file)
    (let ((path (glib-sys:sys-path "test/rtest-gio-file.lisp")))
      (setf file (g:file-new-for-path path))
      (setf info (g:file-query-info file "*" :none))

      (is (<= 3944380000 (g:file-info-modification-date-time info)))
      (is (string= "rtest-gio-file.lisp" (g:file-info-name info)))
      (is (= 8420 (g:file-info-size info))))))

;;;     g_file_info_get_sort_order
;;;     g_file_info_get_symbolic_icon
;;;     g_file_info_get_symlink_target

;;;     g_file_info_has_namespace
;;;     g_file_info_has_attribute
;;;     g_file_info_remove_attribute

(test g-file-info-has-attribute/namespace
  (glib-test:with-check-memory (info file)
    (let ((path (glib-sys:sys-path "test/rtest-gio-file.lisp")))
      (setf file (g:file-new-for-path path))
      (setf info (g:file-query-info file "*" :none))
      ;; Check namespaces
      (is-true (g:file-info-has-namespace info "standard"))
      (is-true (g:file-info-has-namespace info "etag"))
      (is-true (g:file-info-has-namespace info "id"))
      (is-true (g:file-info-has-namespace info "access"))
      (is-true (g:file-info-has-namespace info "time"))
      (is-true (g:file-info-has-namespace info "unix"))
      (is-true (g:file-info-has-namespace info "owner"))
      ;; Check attributes
      (is-true (g:file-info-has-attribute info "standard::type"))
      (is-true (g:file-info-has-attribute info "etag::value"))
      (is-true (g:file-info-has-attribute info "id::file"))
      (is-true (g:file-info-has-attribute info "access::can-read"))
      (is-true (g:file-info-has-attribute info "time::modified"))
      (is-true (g:file-info-has-attribute info "unix::device"))
      (is-true (g:file-info-has-attribute info "owner::user"))
      ;; Remove attribute
      (is-false (g:file-info-remove-attribute info "standard::type"))
      (is-false (g:file-info-has-attribute info "standard::type"))
      (is-false (g:file-info-remove-attribute info "etag::value"))
      (is-false (g:file-info-has-attribute info "etag::value")))))

;;;     g_file_info_list_attributes

(test g-file-info-list-attributes.1
  (glib-test:with-check-memory (info file)
    (let ((path (glib-sys:sys-path "test/rtest-gio-file.lisp")))
      (setf file (g:file-new-for-path path))
      (setf info (g:file-query-info file "standard::*" :none))
      (is (equal '("standard::type"
                   "standard::is-hidden"
                   "standard::is-backup"
                   "standard::is-symlink"
                   "standard::name"
                   "standard::display-name"
                   "standard::edit-name"
                   "standard::copy-name"
                   "standard::icon"
                   "standard::content-type"
                   "standard::fast-content-type"
                   "standard::size"
                   "standard::allocated-size"
                   "standard::symbolic-icon")
       (g:file-info-list-attributes info))))))

#-windows
(test g-file-info-list-attributes.2
  (glib-test:with-check-memory (info file)
    (let ((path (glib-sys:sys-path "test/rtest-gio-file.lisp")))
      (setf file (g:file-new-for-path path))
      (setf info (g:file-query-info file "*" :none))
      (is (equal '("standard::type"
                   "standard::is-hidden"
                   "standard::is-backup"
                   "standard::is-symlink"
                   "standard::name"
                   "standard::display-name"
                   "standard::edit-name"
                   "standard::copy-name"
                   "standard::icon"
                   "standard::content-type"
                   "standard::fast-content-type"
                   "standard::size"
                   "standard::allocated-size"
                   "standard::symbolic-icon"
                   "etag::value"
                   "id::file"
                   "id::filesystem"
                   "access::can-read"
                   "access::can-write"
                   "access::can-execute"
                   "access::can-delete"
                   "access::can-trash"
                   "access::can-rename"
                   "time::modified"
                   "time::modified-usec"
                   "time::access"
                   "time::access-usec"
                   "time::changed"
                   "time::changed-usec"
                   "time::created"
                   "time::created-usec"
                   "time::modified-nsec"
                   "time::access-nsec"
                   "time::created-nsec"
                   "time::changed-nsec"
                   "unix::device"
                   "unix::inode"
                   "unix::mode"
                   "unix::nlink"
                   "unix::uid"
                   "unix::gid"
                   "unix::rdev"
                   "unix::block-size"
                   "unix::blocks"
                   "unix::is-mountpoint"
                   "owner::user"
                   "owner::user-real"
                   "owner::group")
       (g:file-info-list-attributes info))))))

#+windows
(test g-file-info-list-attributes.2
  (glib-test:with-check-memory (info file)
    (let ((path (glib-sys:sys-path "test/rtest-gio-file.lisp")))
      (setf file (g:file-new-for-path path))
      (setf info (g:file-query-info file "*" :none))
      (is (equal '("standard::type" "standard::is-hidden" "standard::is-backup"
                   "standard::is-symlink" "standard::name"
                   "standard::display-name" "standard::edit-name"
                   "standard::copy-name" "standard::icon"
                   "standard::content-type" "standard::fast-content-type"
                   "standard::size" "standard::allocated-size"
                   "standard::symbolic-icon" "etag::value" "id::file"
                   "id::filesystem" "access::can-read" "access::can-write"
                   "access::can-execute" "access::can-delete"
                   "access::can-trash" "access::can-rename" "time::modified"
                   "time::modified-usec" "time::access" "time::access-usec"
                   "time::created" "time::created-usec" "time::modified-nsec"
                   "time::access-nsec" "time::created-nsec" "unix::device"
                   "unix::mode" "unix::nlink" "unix::is-mountpoint"
                   "dos::is-archive" "dos::is-system" "dos::is-mountpoint"
                   "owner::user" "owner::group")
       (g:file-info-list-attributes info))))))

;;;     g_file_info_set_content_type
;;;     g_file_info_set_creation_date_time                  Since 2.70
;;;     g_file_info_set_display_name
;;;     g_file_info_set_edit_name
;;;     g_file_info_set_file_type
;;;     g_file_info_set_icon

;;;     g_file_info_set_is_hidden
;;;     g_file_info_set_is_symlink

;;;     g_file_info_set_modification_date_time



;;;     g_file_info_set_modification_time                   Deprecated 2.62

;;;     g_file_info_set_name

(test g-file-info-name
  (glib-test:with-check-memory (info)
    (is (typep (setf info (g:file-info-new)) 'g:file-info))
    (is (string= "name" (setf (g:file-info-name info) "name")))
    (is (string= "name" (g:file-info-name info)))))

;;;     g_file_info_set_size

(test g-file-info-size
  (glib-test:with-check-memory (info)
    (is (typep (setf info (g:file-info-new)) 'g:file-info))
    (is (= 12000 (setf (g:file-info-size info) 12000)))
    (is (= 12000 (g:file-info-size info)))))

;;;     g_file_info_set_sort_order

(test g-file-info-sort-order
  (glib-test:with-check-memory (info)
    (is (typep (setf info (g:file-info-new)) 'g:file-info))
    (is (= 123 (setf (g:file-info-sort-order info) 123)))
    (is (= 123 (g:file-info-sort-order info)))))

;;;     g_file_info_set_symbolic_icon

(test g-file-info-symbolic-icon
  (glib-test:with-check-memory (info icon)
    (is (typep (setf icon (g:themed-icon-new "gtk-icon")) 'g:icon))
    (is (typep (setf info (g:file-info-new)) 'g:file-info))
    (is (eq icon (setf (g:file-info-symbolic-icon info) icon)))
    (is (eq icon (g:file-info-symbolic-icon info)))
    ;; Remove references
    (is-false (g:file-info-remove-attribute info "standard::symbolic-icon"))))

;;;     g_file_info_set_symlink_target

(test g-file-info-symlink-target
  (glib-test:with-check-memory (info)
    (is (typep (setf info (g:file-info-new)) 'g:file-info))
    (is (string= "target" (setf (g:file-info-symlink-target info) "target")))
    (is (string= "target" (g:file-info-symlink-target info)))))

;;;     g_file_info_unset_attribute_mask

;;; 2026-02-24
