;;; ----------------------------------------------------------------------------
;;; gobject.foreign-gobject-subclassing.lisp
;;;
;;; Copyright (C) 2011 - 2025 Dieter Kaiser
;;;
;;; Permission is hereby granted, free of charge, to any person obtaining a
;;; copy of this software and associated documentation files (the "Software"),
;;; to deal in the Software without restriction, including without limitation
;;; the rights to use, copy, modify, merge, publish, distribute, sublicense,
;;; and/or sell copies of the Software, and to permit persons to whom the
;;; Software is furnished to do so, subject to the following conditions:
;;;
;;; The above copyright notice and this permission notice shall be included in
;;; all copies or substantial portions of the Software.
;;;
;;; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
;;; IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
;;; FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
;;; THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
;;; LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
;;; FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
;;; DEALINGS IN THE SOFTWARE.
;;; ----------------------------------------------------------------------------
;;;
;;; Subclassing from GObject
;;;
;;;     define-gobject-subclass
;;;     define-vtable
;;;
;;;     object-class-init
;;;     object-instance-init
;;; ----------------------------------------------------------------------------

(in-package :gobject)

;;; ----------------------------------------------------------------------------

;; Structure to store the definition of a subclass
(defstruct subclass-info
  gname
  class
  parent
  interfaces
  properties)

;; Stores the subclasses as SUBCLASS-INFO instances
(let ((subclass-infos (make-hash-table :test 'equal)))

  (defun get-subclass-info (gtype)
    (let ((gname (if (stringp gtype)
                     gtype
                     (glib:gtype-name (glib:gtype gtype)))))
      (gethash gname subclass-infos)))

  (defun (setf get-subclass-info) (value gtype)
    (let ((gname (if (stringp gtype)
                     gtype
                     (glib:gtype-name (glib:gtype gtype)))))
      (setf (gethash gname subclass-infos) value)))

  (defun print-subclass-infos ()
    (maphash (lambda (key value) (format t "~a ~a~%" key value))
             subclass-infos)))

;;; ----------------------------------------------------------------------------

;; Definition of a vtable for subclassing an interface

(defstruct vtable-info
  gname
  cname
  methods)

(defstruct vtable-method-info
  slot-name
  name
  return-type
  args
  callback-name
  impl-call
  chained)

;; Stores the subclasses as SUBCLASS-INFO instances
(let ((vtable-infos (make-hash-table :test 'equal)))

  (defun get-vtable-info (gtype)
    (let ((gname (if (stringp gtype)
                     gtype
                     (glib:gtype-name (glib:gtype gtype)))))
      (gethash gname vtable-infos)))

  (defun (setf get-vtable-info) (value gtype)
    (let ((gname (if (stringp gtype)
                     gtype
                     (glib:gtype-name (glib:gtype gtype)))))
      (setf (gethash gname vtable-infos) value)))

  (defun print-vtable-infos ()
    (maphash (lambda (key value) (format t "~a ~a~%" key value))
             vtable-infos)))

;;; ----------------------------------------------------------------------------

(defmethod make-load-form ((object vtable-method-info) &optional environment)
  (declare (ignore environment))
  `(make-vtable-method-info :slot-name ',(vtable-method-info-slot-name object)
                            :name ',(vtable-method-info-name object)
                            :return-type
                            ',(vtable-method-info-return-type object)
                            :args ',(vtable-method-info-args object)
                            :callback-name
                            ',(vtable-method-info-callback-name object)
                            :chained
                            ',(vtable-method-info-chained object)))

(defun vtable-methods (iface-name items)
  (iter (for item in items)
        (when (eq :skip (first item)) (next-iteration))
        (destructuring-bind (name (return-type &rest args)
                                  &key impl-call chained) item
          (for method-name = (intern (format nil "~A-~A-IMPL"
                                             (symbol-name iface-name)
                                             (symbol-name name))))
          (for callback-name = (intern (format nil "~A-~A-CALLBACK"
                                               (symbol-name iface-name)
                                               (symbol-name name))))
          (collect (make-vtable-method-info :slot-name name
                                            :name method-name
                                            :return-type return-type
                                            :args args
                                            :callback-name callback-name
                                            :impl-call impl-call
                                            :chained chained)))))

;;; ----------------------------------------------------------------------------

;; TODO: Consider to use the install-vtable function

(defun interface-init (iface data)
  (destructuring-bind (class-name interface-name)
      (prog1
        (glib:get-stable-pointer-value data)
        (glib:free-stable-pointer data))
    (declare (ignorable class-name))
    (let* ((vtable (get-vtable-info interface-name))
           (vtable-cstruct (when vtable (vtable-info-cname vtable))))
      (when vtable
        (iter (for method in (vtable-info-methods vtable))
              (for cb = (cffi:get-callback
                            (vtable-method-info-callback-name method)))
              (for slot-name = (vtable-method-info-slot-name method))
              (setf (cffi:foreign-slot-value iface
                                            `(:struct ,vtable-cstruct)
                                             slot-name)
                    cb))))))

(cffi:defcallback c-interface-init :void
    ((iface :pointer) (data :pointer))
  (interface-init iface data))

;;; ----------------------------------------------------------------------------

(defun add-interface (name interface)
  (let* ((interface-info (list name interface))
         (interface-info-ptr (glib:allocate-stable-pointer interface-info)))
    (cffi:with-foreign-object (info '(:struct interface-info))
      (setf (cffi:foreign-slot-value info
                                     '(:struct interface-info) :interface-init)
            (cffi:callback c-interface-init)
            (cffi:foreign-slot-value info
                                     '(:struct interface-info) :interface-data)
            interface-info-ptr)
      (type-add-interface-static (glib:gtype name)
                                 (glib:gtype interface)
                                 info))))

(defun add-interfaces (name)
  (let* ((subclass-info (get-subclass-info name))
         (interfaces (subclass-info-interfaces subclass-info)))
    (iter (for interface in interfaces)
          (add-interface name interface))))

;;; ----------------------------------------------------------------------------

(defun wrap-body-with-boxed-translations (args body)
  (if (null args)
      body
      (let ((arg (first args)))
        (destructuring-bind (arg-name arg-type) arg
          (if (and (listp arg-type) (eq 'boxed (first arg-type)))
              (let ((var (gensym))
                    (cffi-type (cffi::parse-type arg-type)))
               `((let ((,var ,arg-name)
                       (,arg-name (cffi:translate-from-foreign ,arg-name
                                                               ,cffi-type)))
                   (unwind-protect
                     (progn
                       ,@(wrap-body-with-boxed-translations (rest args) body))
                     ;; Method for GBoxed types to free resources
                     (glib:cleanup-translated-object-for-callback ,cffi-type
                                                                  ,arg-name
                                                                  ,var)))))
              (wrap-body-with-boxed-translations (rest args) body))))))

(defmacro glib-defcallback (name-and-options return-type args &body body)
  (let* ((c-args (iter (for arg in args)
                       (for (name type) = arg)
                       (if (and (listp type) (eq 'glib:boxed (first type)))
                           (collect `(,name :pointer))
                           (collect arg))))
         (c-body (wrap-body-with-boxed-translations args body)))
   `(cffi:defcallback ,name-and-options ,return-type ,c-args ,@c-body)))

;;; ----------------------------------------------------------------------------

(defun vtable-item->cstruct-item (item)
  (if (eq :skip (first item))
      (rest item)
      (list (first item) :pointer)))

;; TODO: This code can be further extended and optimized
;;       Improve the documentation.

(defmacro define-vtable ((gname name) &body items)
 #+liber-documentation
 "@version{2025-12-28}
  @syntax{(g:define-vtable gname name vfunc) => result}
  @argument[gname]{a string for the @class{g:type-id} name of the subclass}
  @argument[name]{a Lisp symbol for the name of the subclass}
  @argument[vfunc]{a list entry for each virtual function to override}
  @begin{short}
    This macro defines the virtual function table for the @arg{name} subclass.
  @end{short}
  @see-macro{g:define-gobject-subclass}"
  (let ((cname (intern (format nil "~A-VTABLE" (symbol-name name))))
        (methods (vtable-methods name items)))
   `(progn
      (cffi:defcstruct ,cname
                       ,@(mapcar #'vtable-item->cstruct-item items))
      (setf (get-vtable-info ,gname)
            (make-vtable-info :gname ,gname
                              :cname ',cname
                              :methods
                              (list ,@(mapcar #'make-load-form methods))))
    ,@(iter (for method in methods)
            (for args =
                 (if (vtable-method-info-impl-call method)
                     (first (vtable-method-info-impl-call method))
                     (mapcar #'first (vtable-method-info-args method))))
            (for args2 =
                 (when (vtable-method-info-chained method)
                   (iter (for (name type) in (vtable-method-info-args method))
                         (nconcing (list type name)))))
            (for arg1 = (first (vtable-method-info-args method)))
            (for arg2 = (first (rest arg1)))
            ;; Install generic function to replace virtual function
            (collect `(defgeneric ,(vtable-method-info-name method) (,@args)))
            ;; Install a :before or :after method to chain up to the virtual
            ;; function of the parent class
            (collect (when (vtable-method-info-chained method)
                      `(defmethod ,(vtable-method-info-name method)
                                  ,(vtable-method-info-chained method)
                                  ,(if (listp arg2)
                                       `((,(first arg1) ,@(rest arg2)) ,@(rest args))
                                       `((,(first arg1) ,arg2) ,@(rest args)))
                         (let* ((info (get-vtable-info ,gname))
                                (methods (vtable-info-methods info))
                                (method (find-if (lambda (x)
                                                   (eq  ',(vtable-method-info-slot-name method)
                                                        (vtable-method-info-slot-name x)))
                                                 methods))
                                (chained (vtable-method-info-chained method)))
                           (cffi:foreign-funcall-pointer chained () ,@args2
                           ,(vtable-method-info-return-type method))))))
            ;; Install callback function which replaces the virtual function
            (collect `(glib-defcallback
                       ,(vtable-method-info-callback-name method)
                       ,(vtable-method-info-return-type method)
                        (,@(vtable-method-info-args method))
                        (restart-case
                         ,(if (vtable-method-info-impl-call method)
                              `(progn
                                 ,@(rest (vtable-method-info-impl-call method)))
                              `(progn
                                 (,(vtable-method-info-name method)
                                 ,@(mapcar #'first
                                           (vtable-method-info-args method)))))
                          (return-from-interface-method-implementation
                            (v)
                            :interactive
                            (lambda () (list (eval (read)))) v))))))))

(export 'define-vtable)

;;; ----------------------------------------------------------------------------

;; TODO: Improve the documentation

(defgeneric object-instance-init (subclass instance class))

 #+liber-documentation
(setf (documentation 'object-instance-init 'function)
 "@version{2025-12-28}
  @argument[subclass]{a @class{g:object} class type specifier}
  @argument[instance]{a foreign pointer to the C instance}
  @argument[class]{a foreign pointer to the C class}
  @begin{short}
    The primary method initializes the new C instance of @arg{class}.
  @end{short}
  @see-class{g:object}
  @see-macro{g:define-gobject-subclass}
  @see-generic{g:object-class-init}")

(defmethod object-instance-init (subclass instance cclass)
  (declare (ignorable subclass))
  (unless (or *current-creating-object*
              *currently-making-object-p*
              (get-gobject-for-pointer instance))
    (let* ((gtype (type-from-class cclass))
           (subclass (subclass-info-class (get-subclass-info gtype))))
      (make-instance subclass :pointer instance))))

(cffi:defcallback instance-init-cb :void
                  ((instance :pointer) (cclass :pointer))
  (let ((subclass (glib:symbol-for-gtype (type-from-class cclass))))
    (object-instance-init (find-class subclass) instance cclass)))

(export 'object-instance-init)

;;; ----------------------------------------------------------------------------

;; Helper functions for PROPERTY->PARAM-SPEC
(defun minimum-foreign-integer (type &optional (signed t))
  (if signed
      (- (ash 1 (1- (* 8 (cffi:foreign-type-size type)))))
      0))

(defun maximum-foreign-integer (type &optional (signed t))
  (if signed
      (1- (ash 1 (1- (* 8 (cffi:foreign-type-size type)))))
      (1- (ash 1 (* 8 (cffi:foreign-type-size type))))))

;;; ----------------------------------------------------------------------------

;; Create and return a GParamSpec for the property we wish to install
;; TODO: This must be extended whenever a new fundamental GType is introduced
(defun property->param-spec (property)
  (destructuring-bind (property-name
                       property-type
                       accessor
                       property-get-fn
                       property-set-fn)
      property
    (declare (ignore accessor))
    (let ((property-gtype (glib:gtype property-type))
          (flags (append (when property-get-fn (list :readable))
                         (when property-set-fn (list :writable)))))
      (ev-case (type-fundamental property-gtype)
        (nil
         (error "GValue is of invalid type ~A (~A)"
                property-gtype (glib:gtype-name property-gtype)))
        ((glib:gtype "void") nil)
        ((glib:gtype "gchar")
         (param-spec-char property-name
                          property-name
                          property-name
                          (minimum-foreign-integer :char)
                          (maximum-foreign-integer :char)
                          0
                          flags))
        ((glib:gtype "guchar")
         (param-spec-uchar property-name
                           property-name
                           property-name
                           (minimum-foreign-integer :uchar nil)
                           (maximum-foreign-integer :uchar nil)
                           0
                           flags))
        ((glib:gtype "gboolean")
         (param-spec-boolean property-name
                             property-name
                             property-name
                             nil
                             flags))
        ((glib:gtype "gint")
         (param-spec-int property-name
                         property-name
                         property-name
                         (minimum-foreign-integer :int)
                         (maximum-foreign-integer :int)
                         0
                         flags))
        ((glib:gtype "guint")
         (param-spec-uint property-name
                          property-name
                          property-name
                          (minimum-foreign-integer :uint nil)
                          (maximum-foreign-integer :uint nil)
                          0
                          flags))
        ((glib:gtype "glong")
         (param-spec-long property-name
                          property-name
                          property-name
                          (minimum-foreign-integer :long)
                          (maximum-foreign-integer :long)
                          0
                          flags))
        ((glib:gtype "gulong")
         (param-spec-ulong property-name
                           property-name
                           property-name
                           (minimum-foreign-integer :ulong nil)
                           (maximum-foreign-integer :ulong nil)
                           0
                           flags))
        ((glib:gtype "gint64")
         (param-spec-int64 property-name
                           property-name
                           property-name
                           (minimum-foreign-integer :int64)
                           (maximum-foreign-integer :int64)
                           0
                           flags))
        ((glib:gtype "guint64")
         (param-spec-uint64 property-name
                            property-name
                            property-name
                            (minimum-foreign-integer :uint64 nil)
                            (maximum-foreign-integer :uint64 t)
                            0
                            flags))
        ((glib:gtype "GEnum")
         (param-spec-enum property-name
                          property-name
                          property-name
                          property-gtype
                          (enum-item-value
                            (first (get-enum-items property-gtype)))
                          flags))
        ((glib:gtype "GFlags")
         (param-spec-enum property-name
                          property-name
                          property-name
                          property-gtype
                          (flags-item-value
                            (first (get-flags-items property-gtype)))
                          flags))
        ((glib:gtype "gfloat")
         (param-spec-float property-name
                           property-name
                           property-name
                           most-negative-single-float
                           most-positive-single-float
                           0.0
                           flags))
        ((glib:gtype "gdouble")
         (param-spec-double property-name
                            property-name
                            property-name
                            most-negative-double-float
                            most-positive-double-float
                            0.0d0
                            flags))
        ((glib:gtype "gchararray")
         (param-spec-string property-name
                            property-name
                            property-name
                            ""
                            flags))
        ((glib:gtype "gpointer")
         (param-spec-pointer property-name
                             property-name
                             property-name
                             flags))
        ((glib:gtype "GBoxed")
         (param-spec-boxed property-name
                           property-name
                           property-name
                           property-gtype
                           flags))
        ((glib:gtype "GObject")
         (param-spec-object property-name
                            property-name
                            property-name
                            property-gtype
                            flags))
        (t
         (error "Unknown type: ~A (~A)"
                property-gtype (glib:gtype-name property-gtype)))))))

;;; ----------------------------------------------------------------------------

(defun object-property-get (instance property-id g-value pspec)
  (declare (ignore property-id))
  (let* ((object (get-gobject-for-pointer instance))
         (property-name (cffi:foreign-slot-value pspec
                                                 '(:struct param-spec)
                                                 :name))
         (property-type (cffi:foreign-slot-value pspec
                                                 '(:struct param-spec)
                                                 :value-type))
         (gname (glib:gtype-name
                        (cffi:foreign-slot-value pspec
                                                 '(:struct param-spec)
                                                 :owner-type)))
         (subclass-info (get-subclass-info gname))
         (property-info (find property-name
                              (subclass-info-properties subclass-info)
                              :test 'string= :key 'first))
         (property-get-fn (third property-info)))
    (assert (fourth property-info))
    (let ((value (restart-case
                   (funcall property-get-fn object)
                   (return-from-property-getter (value)
                                                :interactive
                                                (lambda ()
                                                  (format t "Enter new value: ")
                                                  (list (eval (read))))
                                                value))))
      (set-gvalue g-value value property-type))))

(cffi:defcallback c-object-property-get :void
    ((instance :pointer)
     (property-id :uint)
     (value :pointer)
     (pspec :pointer))
  (object-property-get instance property-id value pspec))

;;; ----------------------------------------------------------------------------

(defun object-property-set (object property-id value pspec)
  (declare (ignore property-id))
  (let* ((lisp-object (get-gobject-for-pointer object))
         (property-name (cffi:foreign-slot-value pspec
                                                 '(:struct param-spec) :name))
         (type-name (glib:gtype-name
                        (cffi:foreign-slot-value pspec
                                                 '(:struct param-spec)
                                                 :owner-type)))
         (lisp-type-info (get-subclass-info type-name))
         (property-info (find property-name
                              (subclass-info-properties lisp-type-info)
                              :test 'string= :key 'first))
         (property-set-fn (third property-info))
         (new-value (value-get value)))
    (assert (fifth property-info))
    (restart-case
      (funcall (fdefinition (list 'setf property-set-fn)) new-value lisp-object)
      (return-without-error-from-property-setter () nil))))

(cffi:defcallback c-object-property-set :void
    ((object :pointer) (property-id :uint) (value :pointer) (pspec :pointer))
  (object-property-set object property-id value pspec))

;;; ----------------------------------------------------------------------------

(defun install-vtable (gtype)
  (let* ((cclass (type-class-ref gtype))
         (vtable (get-vtable-info gtype))
         (vtable-cstruct (when vtable (vtable-info-cname vtable))))
    (when vtable
      (iter (for method in (vtable-info-methods vtable))
            (for callback-name = (vtable-method-info-callback-name method))
            (for slot-name = (vtable-method-info-slot-name method))
            (when (vtable-method-info-chained method)
              ;; Store function pointer for virtual function of the parent class
              (setf (vtable-method-info-chained method)
                    (cffi:foreign-slot-value cclass
                                             `(:struct ,vtable-cstruct)
                                             slot-name)))
            ;; Install the virtual function
            (setf (cffi:foreign-slot-value cclass
                                           `(:struct ,vtable-cstruct)
                                           slot-name)
                  (cffi:get-callback callback-name))))))

;;; ----------------------------------------------------------------------------

;; TODO: Improve the documentation

(defgeneric object-class-init (subclass class data))

 #+liber-documentation
(setf (documentation 'object-class-init 'function)
 "@version{2025-12-28}
  @argument[subclass]{a @class{g:object} class type specifier}
  @argument[class]{a foreign pointer to the C class}
  @argument[data]{a foreign pointer, always the @code{cffi:null-pointer} value}
  @begin{short}
    The primary method installs the properties for the object class and the
    virtual getter and setter methods for these properties.
  @end{short}
  If present, this function installs the virtual function table for the object
  class.
  @see-class{g:object}
  @see-macro{g:define-gobject-subclass}
  @see-generic{g:object-instance-init}")

(defmethod object-class-init (subclass cclass data)
  (declare (ignorable subclass data))
  (let* ((gtype (type-from-class cclass))
         (subclass-info (get-subclass-info gtype)))
    ;; Initialize getter and setter methods for the object class
    (setf (object-class-get-property cclass)
          (cffi:callback c-object-property-get)
          (object-class-set-property cclass)
          (cffi:callback c-object-property-set))
    ;; Install the properties for the object class
    (iter (for property in (subclass-info-properties subclass-info))
          (for pspec = (property->param-spec property))
          (for property-id from 123) ; FIXME: This is a magic number!?
          (%object-class-install-property cclass property-id pspec))
    ;; Install vtable for the subclass
    (install-vtable gtype)))

(cffi:defcallback class-init-cb :void
                  ((cclass :pointer) (data :pointer))
  (let ((subclass (glib:symbol-for-gtype (type-from-class cclass))))
    (object-class-init (find-class subclass) cclass data)))

(export 'object-class-init)

;;; ----------------------------------------------------------------------------

;; Filter properties that we will register
(defun filter-properties-to-register (properties)
  (iter (for property in properties)
        (when (or (eq :cl (first property))
                  (eq :cffi (first property)))
          (next-iteration))
        (collect (list (third property)
                       (fourth property)
                       (second property)
                       (fifth property)
                       (sixth property)))))

(defun subclass-property->slot (class property &optional (initform-p nil))
  (declare (ignorable class))
  (cond ((gobject-property-p property)
         `(,(property-name property)
           :accessor ,(property-accessor property)
           :initarg ,(intern (string-upcase (property-name property))
                             (find-package :keyword))
           ,@(when initform-p
               (let* (;; Get GParamSpec for the GType of the property
                      (pspec (property->param-spec
                                 (list (gobject-property-gname property)
                                       (gobject-property-gtype property)
                                       (gobject-property-accessor property)
                                       nil nil)))
                      ;; Get default value from GParamSpec for initialization
                      (default (value-get (param-spec-default-value pspec))))
                 `(:initform ,default)))))
        ((cffi-property-p property)
         `(,(property-name property)
           :accessor ,(property-accessor property)
           ,@(when (not (null (cffi-property-writer property)))
               `(:initarg
                 ,(intern (string-upcase (property-name property))
                          (find-package :keyword))))
           :reader ,(cffi-property-reader property)
           :writer ,(cffi-property-writer property)))
        ((cl-property-p property)
         `(,(property-name property)
           ,@(cl-property-args property)))))

;;; ----------------------------------------------------------------------------

;; TODO: Improve the documentation

(defmacro define-gobject-subclass (gname name
                                    (&key (superclass 'object)
                                          (export t)
                                          interfaces)
                                    (&rest properties))
 #+liber-documentation
 "@version{2025-12-28}
  @syntax{(g:define-gobject-subclass gname name (keywords) (properties))
    => subclass}
  @argument[gname]{a string for the new @class{g:type-t} name of the subclass}
  @argument[name]{a Lisp symbol for the name of the new subclass}
  @argument[keywords]{valid keywords are @code{:superclass}, @code{:export}
    and @code{:interfaces}}
  @argument[:superclass]{a Lisp type specifier for the superclass}
  @argument[:export]{a boolean whether to export the subclass symbols}
  @argument[:interfaces]{a List for the @class{g:type-t} names of the
    interfaces for the subclass}
  @argument[properties]{a list for the properties of the new subclass}
  @begin{short}
    This macro defines a new subclass from @arg{superclass}.
  @end{short}
  @see-class{g:object}
  @see-macro{g:define-vtable}"
  (let ((props (mapcar #'parse-property properties))
        (parent (cond ((stringp superclass)
                        superclass)
                      ((eq 'object superclass)
                       "GObject")
                      (t
                       (gobject-class-gname (find-class superclass))))))
    (setf properties (filter-properties-to-register properties))
    `(progn
       ;; Store the definition as subclass-info
       (setf (get-subclass-info ,gname)
             (make-subclass-info :gname ,gname
                                 :class ',name
                                 :parent ,parent
                                 :interfaces ',interfaces
                                 :properties ',properties))
       ;; Declare the Lisp class
       (defclass ,name (,@(when (and superclass
                                     (not (eq superclass 'object)))
                            (list superclass))
                        ,@(mapcar #'interface->lisp-class-name interfaces))
         ;; Generate the slot definitions from the given properties
         (,@(mapcar (lambda (property)
                       (subclass-property->slot name property t))
                     props))
         (:gname . ,gname)
         (:metaclass gobject-class))
       ;; Register the class
       (glib-init:at-init (',name)
         (cffi:with-foreign-object (query '(:struct type-query))
           (type-query (glib:gtype ,parent) query)
           (type-register-static-simple
               (glib:gtype ,parent)
               ,gname
               (cffi:foreign-slot-value query '(:struct type-query) :class-size)
               (cffi:callback class-init-cb)
               (cffi:foreign-slot-value query '(:struct type-query) :instance-size)
               (cffi:callback instance-init-cb)
               nil))
         (add-interfaces ,gname)
         ;; Register Lisp symbol for GType
         (setf (glib:symbol-for-gtype ,gname) ',name))
       ;; Initializer for the instance of the subclass
       (defmethod initialize-instance :before ((object ,name) &key pointer)
         (unless (or pointer
                     (and (slot-boundp object 'pointer)
                          (object-pointer object)))
           (setf (object-pointer object)
                 (call-gobject-constructor ,gname nil nil)
                 (object-has-reference object) t)))
       ;; Export accessible symbols
       ,@(when export
           (cons `(export ',name
                           (find-package
                             ,(package-name (symbol-package name))))
                 (mapcar (lambda (property)
                          `(export
                            ',(intern
                                (typecase property
                                  ;; This code stems from an issue reported by
                                  ;; André A. Gomes:
                                  ;; (https://github.com/crategus/cl-cffi-glib/issues/8)
                                  ;; TODO:
                                  ;; It exports a writer, or a reader, or an
                                  ;; accessor method. However, multiple methods
                                  ;; can be defined for a slot. Therefore,
                                  ;; further code modification is necessary.
                                  ;; This would require more effort.
                                  ;; Alternatively, the user can manually export
                                  ;; additional symbols. This would require a
                                  ;; corresponding documentation of the macro.
                                  (cl-property
                                   (symbol-name
                                     (or (getf (cl-property-args property) :reader)
                                         (getf (cl-property-args property) :writer)
                                         (getf (cl-property-args property) :accessor))))
                                  (cffi-property
                                    (symbol-name
                                      (cffi-property-accessor property)))
                                  (t
                                   (symbol-name
                                     (gobject-property-accessor property))))
                                (symbol-package name))
                             (find-package
                              ,(package-name (symbol-package name)))))
                         props))))))

(export 'define-gobject-subclass)

;;; --- End of file gobject.foreign-gobject-subclassing.lisp -------------------
