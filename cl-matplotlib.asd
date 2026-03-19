(defsystem #:cl-matplotlib
  :version "0.0.0"
  :description "Interactive matlab like plotting experience using python+matplotlib"
  :author "Andrew J. Berkley <ajberkley@gmail.com>"
  :long-name "Interactive matlab like plotting experience using python+matplotlib"
  :pathname "src/"
  :depends-on (#:py4cl2
	       #:alexandria
	       )
  :components ((:file "cl-matplotlib"))
  :license :BSD-3
  :in-order-to ((asdf:test-op (asdf:test-op :cl-matplotlib))))

(defsystem #:cl-matplotlib/tests
  :description "Unit tests for cl-matplotlib"
  :author "Andrew J. Berkley <ajberkley@gmail.com>"
  :license :BSD-3
  :depends-on (#:parachute #:cl-matplotlib)
  :pathname "test/"
  :components ()
  :perform (test-op (o c) (uiop:symbol-call :parachute :test :cl-matplotlib-tests)))
