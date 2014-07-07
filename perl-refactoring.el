;;; perl-refactoring.el --- Emacs front end of App::PRT

;; Copyright (C) 2014 by Syohei YOSHIDA

;; Author: Syohei YOSHIDA <syohex@gmail.com>
;; URL: https://github.com/syohex/emacs-perl-refactoring
;; Version: 0.01

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;;; Code:

(require 'cl-lib)
(require 'cperl-mode)

(defgroup perl-refactoring nil
  "perl refactoring by App::PRT"
  :group 'perl)

(defcustom perl-refactoring-default-target "lib/**/*.pm  t/**/*.t"
  "Default target files. This is expanded by File::Zglob::zglob"
  :type 'string
  :group 'perl-refactoring)

(defun perl-refactoring--root-directory ()
  (cl-loop for file in '("cpanfile" "Build.PL" "Makefile.PL")
           when (locate-dominating-file default-directory file)
           return (expand-file-name it)
           finally (error "Can't find project root")))

(defun perl-refactoring--expand-wildcard (root target)
  (with-temp-buffer
    (let ((default-directory root)
          (args (list "-MFile::Zglob" "-wle"
                      (format "print for zglob(qw{%s})" target))))
      (unless (zerop (apply 'call-process "perl" nil t nil args))
        (error "Failed: expand target glob(Please check File::Zglob is installed ?)"))
      (goto-char (point-min))
      (let ((files nil))
        (while (not (eobp))
          (push (buffer-substring-no-properties
                 (line-beginning-position) (line-end-position))
                files)
          (forward-line 1))
        files))))

(defun perl-refactoring--read-from ()
  (let* ((default-value (cperl-word-at-point))
         (prompt (format "Replace [Default %s]: " default-value)))
    (read-string prompt nil nil default-value)))

(defun perl-refactoring--read-to (from)
  (let ((prompt (format "Replace '%s' to : " from)))
    (read-string prompt)))

(defun perl-refactoring--read-target ()
  (let ((prompt (format "Target [Default %s]: " perl-refactoring-default-target)))
    (read-string prompt nil nil perl-refactoring-default-target)))

;; This function should be implemented asynchronous
(defun perl-refactoring--exec-prt (subcmd root from to target)
  (let ((default-directory root))
    (unless (zerop (apply 'call-process "prt" nil nil nil subcmd from to target))
      (error "Failed: '%s'" (format "prt %s %s %s %s"
                                    subcmd from to
                                    (mapconcat 'identity target " "))))
    (message "Success: prt %s" subcmd)))

(defun perl-refactoring--apply-buffers (func root files)
  (cl-loop with paths = (mapcar (lambda (f) (concat root f)) files)
           for buf in (buffer-list)
           for bufname = (buffer-file-name buf)
           when (and bufname (member bufname paths))
           do
           (with-current-buffer buf
             (funcall func))))

(defun perl-refactoring--save-buffers (root files)
  (perl-refactoring--apply-buffers 'save-buffer root files))

(defun perl-refactoring--revert-buffers (root files)
  (perl-refactoring--apply-buffers
   (lambda () (revert-buffer t t)) root files))

;;;###autoload
(defun perl-refactoring-replace-token (from to target)
  (interactive
   (let (from)
     (list
      (setq from (perl-refactoring--read-from))
      (perl-refactoring--read-to from)
      (perl-refactoring--read-target))))
  (let* ((project-root (perl-refactoring--root-directory))
         (expanded (perl-refactoring--expand-wildcard project-root target)))
    (perl-refactoring--save-buffers project-root expanded)
    (perl-refactoring--exec-prt "replace_token" project-root from to expanded)
    (perl-refactoring--revert-buffers project-root expanded)))

(provide 'perl-refactoring)

;;; perl-refactoring.el ends here
